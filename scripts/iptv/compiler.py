# scripts/iptv/compiler.py
"""
mytv-android 纯 IPv4 流媒体编译引擎 (Pure IPv4 IPTV Subscription Compiler)
功能：
1. 异步多源抓取 (FanMingMing, BurningC4, Guovin, YanG, iptv-org)
2. 严格 IPv4 门禁 (正则阻断 IPv6 字面量 + socket.AF_INET 单栈解析验证)
3. 声明式频道编目匹配与归一化去重
4. aiohttp AF_INET 异步并发探活与 TTFB 测速排序
5. 双保险保底降级机制与标准 M3U / TXT 双格式序列化输出
"""

import argparse
import asyncio
import ipaddress
import json
import logging
import os
import re
import socket
import sys
import time
import urllib.parse
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple

import aiohttp

# 日志输出配置
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("iptv_compiler")


@dataclass
class CandidateStream:
    """候选流媒体实体"""
    raw_title: str
    url: str
    source_name: str
    group_title: str = ""
    tvg_id: str = ""
    tvg_name: str = ""
    tvg_logo: str = ""
    is_ipv4_valid: bool = False
    is_alive: bool = False
    ttfb_ms: int = 999999


@dataclass
class ChannelSpec:
    """声明式频道定义"""
    name: str
    tvg_id: str
    tvg_name: str
    logo: str
    match_patterns: List[re.Pattern]
    group_name: str
    active_streams: List[CandidateStream] = field(default_factory=list)


class IPv4Gate:
    """纯 IPv4 单栈与字面量验证门禁"""

    IPV6_LITERAL_REGEX = re.compile(r"://\[[0-9a-fA-F:]+\]")
    _dns_cache: Dict[str, bool] = {}

    @classmethod
    def is_ipv4_strict(cls, url: str) -> bool:
        """
        验证给定的 URL 是否满足纯 IPv4 约束：
        1. 阻断任何 IPv6 字面量形式 (如 ://[2409:...])
        2. 校验 Host 域名解析是否包含有效 IPv4 A 记录，阻断纯 IPv6 AAAA 域名
        """
        if not url or not url.startswith(("http://", "https://")):
            return False

        # 门禁 1：正则拦截 IPv6 字面量
        if cls.IPV6_LITERAL_REGEX.search(url):
            return False

        try:
            parsed = urllib.parse.urlparse(url)
            hostname = parsed.hostname
            if not hostname:
                return False

            # 门禁 2：直接包含冒号的原始 IPv6 主机名
            if ":" in hostname and not hostname.startswith("["):
                return False

            # 若为主机名已是字面量 IPv4
            try:
                ip = ipaddress.ip_address(hostname)
                return isinstance(ip, ipaddress.IPv4Address)
            except ValueError:
                pass  # 属于域名，执行 DNS A 记录探测

            # 门禁 3：域名 DNS 解析缓存与 AF_INET 验证
            if hostname in cls._dns_cache:
                return cls._dns_cache[hostname]

            # 尝试通过 AF_INET 查询 A 记录，设置超时防止挂起
            orig_timeout = socket.getdefaulttimeout()
            try:
                socket.setdefaulttimeout(1.5)
                addr_info = socket.getaddrinfo(hostname, 80, family=socket.AF_INET, type=socket.SOCK_STREAM)
                is_valid = len(addr_info) > 0
                cls._dns_cache[hostname] = is_valid
                return is_valid
            finally:
                socket.setdefaulttimeout(orig_timeout)

        except (socket.gaierror, socket.herror, TimeoutError, OSError):
            cls._dns_cache[hostname] = False
            return False


class UpstreamFetcher:
    """上游源异步抓取器"""

    def __init__(self, session: aiohttp.ClientSession):
        self.session = session

    async def fetch_source(self, source_info: dict) -> Tuple[str, str]:
        """抓取单个上游源内容，支持主镜像容灾"""
        name = source_info.get("name", "Unknown")
        primary_url = source_info.get("url")
        mirror_url = source_info.get("mirror")
        timeout = aiohttp.ClientTimeout(total=15)
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }

        for attempt_url in [primary_url, mirror_url]:
            if not attempt_url:
                continue
            try:
                logger.info(f"正在拉取上游源 [{name}] 从 {attempt_url} ...")
                async with self.session.get(attempt_url, timeout=timeout, headers=headers) as response:
                    if response.status == 200:
                        content = await response.text(encoding="utf-8", errors="ignore")
                        logger.info(f"✅ 上游源 [{name}] 拉取成功，数据大小: {len(content)} 字节")
                        return name, content
                    else:
                        logger.warning(f"⚠️ 上游源 [{name}] 响应状态异常: HTTP {response.status}")
            except Exception as e:
                logger.warning(f"⚠️ 上游源 [{name}] 拉取失败 ({attempt_url}): {e}")

        logger.error(f"❌ 上游源 [{name}] 所有可用地址拉取均失败，跳过该源")
        return name, ""


class ContentParser:
    """M3U 与 TXT 格式内容解析引擎"""

    EXTINF_REGEX = re.compile(
        r'#EXTINF:-1\s*(?:tvg-id="([^"]*)")?\s*(?:tvg-name="([^"]*)")?\s*(?:tvg-logo="([^"]*)")?\s*(?:group-title="([^"]*)")?[^,]*,(.*)'
    )

    @classmethod
    def parse_m3u(cls, content: str, source_name: str) -> List[CandidateStream]:
        """解析标准扩展 M3U8/M3U 内容"""
        candidates: List[CandidateStream] = []
        lines = content.splitlines()
        current_meta: Optional[Tuple[str, str, str, str, str]] = None

        for line in lines:
            line = line.strip()
            if not line:
                continue
            if line.startswith("#EXTINF:"):
                match = cls.EXTINF_REGEX.search(line)
                if match:
                    tvg_id = match.group(1) or ""
                    tvg_name = match.group(2) or ""
                    tvg_logo = match.group(3) or ""
                    group_title = match.group(4) or ""
                    title = match.group(5) or ""
                    current_meta = (tvg_id, tvg_name, tvg_logo, group_title, title.strip())
                else:
                    # 简易逗号分隔备选
                    title = line.split(",")[-1].strip()
                    current_meta = ("", "", "", "", title)
            elif line.startswith("#"):
                continue  # 忽略其他 M3U 指令标签
            else:
                # 流媒体 URL 行
                url = line
                if current_meta:
                    tvg_id, tvg_name, tvg_logo, group_title, title = current_meta
                else:
                    tvg_id, tvg_name, tvg_logo, group_title, title = "", "", "", "", "未知频道"

                candidates.append(
                    CandidateStream(
                        raw_title=title,
                        url=url,
                        source_name=source_name,
                        group_title=group_title,
                        tvg_id=tvg_id,
                        tvg_name=tvg_name,
                        tvg_logo=tvg_logo,
                    )
                )
                current_meta = None

        return candidates

    @classmethod
    def parse_txt(cls, content: str, source_name: str) -> List[CandidateStream]:
        """解析标准 TXT 格式 (组名,#genre# 分隔)"""
        candidates: List[CandidateStream] = []
        current_group = "默认分组"
        lines = content.splitlines()

        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ",#genre#" in line:
                current_group = line.split(",#genre#")[0].strip()
                continue

            parts = line.split(",")
            if len(parts) >= 2:
                title = parts[0].strip()
                url = parts[1].strip()
                candidates.append(
                    CandidateStream(
                        raw_title=title,
                        url=url,
                        source_name=source_name,
                        group_title=current_group,
                    )
                )

        return candidates


class AsyncProbeEngine:
    """异步单栈探活与 TTFB 测速引擎"""

    def __init__(self, timeout_seconds: int = 3, concurrency: int = 50):
        self.timeout_seconds = timeout_seconds
        self.semaphore = asyncio.Semaphore(concurrency)

    async def probe_stream(self, session: aiohttp.ClientSession, stream: CandidateStream) -> CandidateStream:
        """对单个流媒体进行纯 IPv4 单栈首包探活与延迟评估"""
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Range": "bytes=0-1024",  # 首部字节试探，降低流量消耗
        }
        timeout = aiohttp.ClientTimeout(total=self.timeout_seconds, connect=2.0)

        async with self.semaphore:
            start_time = time.perf_counter()
            try:
                async with session.get(stream.url, timeout=timeout, headers=headers, allow_redirects=True) as resp:
                    if resp.status in (200, 206):
                        # 读取首包切片以验证数据流可达
                        await resp.content.read(512)
                        elapsed_ms = int((time.perf_counter() - start_time) * 1000)
                        stream.is_alive = True
                        stream.ttfb_ms = elapsed_ms
                    else:
                        stream.is_alive = False
            except Exception:
                stream.is_alive = False

        return stream


class IPTVCompiler:
    """IPTV 订阅核心编译总控"""

    def __init__(self, manifest_path: str, output_dir: str, skip_probe: bool = False, max_lines_override: Optional[int] = None):
        self.manifest_path = manifest_path
        self.output_dir = output_dir
        self.skip_probe = skip_probe
        self.max_lines_override = max_lines_override
        self.manifest: dict = {}
        self.channels_spec: List[ChannelSpec] = []
        self.all_candidates: List[CandidateStream] = []

    def load_manifest(self):
        """加载声明式频道清单"""
        if not os.path.exists(self.manifest_path):
            raise FileNotFoundError(f"配置文件未找到: {self.manifest_path}")

        with open(self.manifest_path, "r", encoding="utf-8") as f:
            self.manifest = json.load(f)

        self.channels_spec = []  # 重置以避免重复加载导致列表倍增

        settings = self.manifest.get("settings", {})
        self.max_lines = self.max_lines_override or settings.get("max_lines_per_channel", 4)
        self.probe_timeout = settings.get("probe_timeout_seconds", 3)
        self.concurrent_probes = settings.get("concurrent_probes", 50)
        self.ipv4_only = settings.get("ipv4_only", True)
        self.epg_urls = settings.get("epg_urls", [])
        self.default_logo_base = settings.get("default_logo_base", "")

        # 编译所有正则匹配器
        for group in self.manifest.get("groups", []):
            group_name = group.get("name", "未分类")
            for ch in group.get("channels", []):
                patterns = [re.compile(p) for p in ch.get("match_patterns", [])]
                logo_file = ch.get("logo", "")
                logo_url = (self.default_logo_base + logo_file) if (logo_file and not logo_file.startswith("http")) else logo_file

                spec = ChannelSpec(
                    name=ch.get("name"),
                    tvg_id=ch.get("tvg_id", ch.get("name")),
                    tvg_name=ch.get("tvg_name", ch.get("name")),
                    logo=logo_url,
                    match_patterns=patterns,
                    group_name=group_name,
                )
                self.channels_spec.append(spec)

        logger.info(f"成功加载配置契约: 包含 {len(self.channels_spec)} 个频道，分组数: {len(self.manifest.get('groups', []))}")

    async def fetch_all_upstreams(self) -> List[CandidateStream]:
        """抓取并解析所有上游源池"""
        upstream_list = self.manifest.get("upstream_sources", [])
        candidates: List[CandidateStream] = []

        # 创建纯 IPv4 单栈 ClientSession
        connector = aiohttp.TCPConnector(family=socket.AF_INET, ssl=False, ttl_dns_cache=300)
        async with aiohttp.ClientSession(connector=connector) as session:
            fetcher = UpstreamFetcher(session)
            tasks = [fetcher.fetch_source(src) for src in upstream_list]
            results = await asyncio.gather(*tasks)

            for name, content in results:
                if not content:
                    continue
                if "#EXTM3U" in content:
                    parsed = ContentParser.parse_m3u(content, name)
                else:
                    parsed = ContentParser.parse_txt(content, name)
                logger.info(f"源 [{name}] 解析产出候选链接: {len(parsed)} 条")
                candidates.extend(parsed)

        return candidates

    def filter_and_match(self, raw_candidates: List[CandidateStream]) -> Dict[str, List[CandidateStream]]:
        """执行严格 IPv4 门禁过滤与正则命中归集"""
        matched_map: Dict[str, List[CandidateStream]] = {spec.name: [] for spec in self.channels_spec}
        seen_urls_per_channel: Dict[str, Set[str]] = {spec.name: set() for spec in self.channels_spec}

        ipv4_filtered_count = 0
        total_candidates = len(raw_candidates)

        for candidate in raw_candidates:
            # 1. 严格纯 IPv4 门禁
            if self.ipv4_only:
                if not IPv4Gate.is_ipv4_strict(candidate.url):
                    ipv4_filtered_count += 1
                    continue
            candidate.is_ipv4_valid = True

            # 2. 遍历频道正则白名单匹配
            for spec in self.channels_spec:
                is_hit = False
                for pattern in spec.match_patterns:
                    if pattern.search(candidate.raw_title):
                        is_hit = True
                        break

                if is_hit:
                    # 去除单频道内重复 URL
                    if candidate.url not in seen_urls_per_channel[spec.name]:
                        seen_urls_per_channel[spec.name].add(candidate.url)
                        # 继承频道的 tvg_id 与 logo
                        candidate.tvg_id = spec.tvg_id
                        candidate.tvg_name = spec.tvg_name
                        candidate.tvg_logo = spec.logo
                        candidate.group_title = spec.group_name
                        matched_map[spec.name].append(candidate)

        logger.info(f"IPv4 门禁过滤完成: 原始候选 {total_candidates} 条，阻断非 IPv4/无效域名 {ipv4_filtered_count} 条")
        for spec in self.channels_spec:
            count = len(matched_map[spec.name])
            if count == 0:
                logger.warning(f"⚠️ 频道 [{spec.name}] 未在任何上游源中命中候选线路")
            else:
                logger.debug(f"频道 [{spec.name}] 命中候选 {count} 条")

        return matched_map

    def process_matched_channels(self, matched_map: Dict[str, List[CandidateStream]]):
        """整理各频道可用列表，按延迟排序与保留最优线路"""
        for spec in self.channels_spec:
            streams = matched_map[spec.name]
            alive_streams = [s for s in streams if s.is_alive]
            # 按 TTFB 延迟升序排序
            alive_streams.sort(key=lambda x: x.ttfb_ms)

            # 截取最优 N 条
            spec.active_streams = alive_streams[: self.max_lines]

            if not spec.active_streams and streams:
                logger.warning(f"⚠️ 频道 [{spec.name}] 探测后无存活线路！保留首条备选线路作为保底")
                spec.active_streams = [streams[0]]

    async def probe_all_channels(self, matched_map: Dict[str, List[CandidateStream]]):
        """执行异步并发测速与排序截取"""
        all_to_probe: List[CandidateStream] = []
        for streams in matched_map.values():
            all_to_probe.extend(streams)

        if self.skip_probe:
            logger.info("已指定 --skip-probe 参数，跳过网络测速探活")
            for stream in all_to_probe:
                stream.is_alive = True
                stream.ttfb_ms = 100
        else:
            logger.info(f"开始对 {len(all_to_probe)} 条纯 IPv4 候选线路进行并发探活测速 (超时: {self.probe_timeout}s, 并发: {self.concurrent_probes}) ...")
            connector = aiohttp.TCPConnector(family=socket.AF_INET, ssl=False)
            async with aiohttp.ClientSession(connector=connector) as session:
                prober = AsyncProbeEngine(timeout_seconds=self.probe_timeout, concurrency=self.concurrent_probes)
                tasks = [prober.probe_stream(session, s) for s in all_to_probe]
                await asyncio.gather(*tasks)

        self.process_matched_channels(matched_map)

    def compile_offline(self, raw_candidates: List[CandidateStream]):
        """离线模式或单测专用的确定性内存编译流水线"""
        self.load_manifest()
        matched_map = self.filter_and_match(raw_candidates)
        for streams in matched_map.values():
            for s in streams:
                s.is_alive = True
                s.ttfb_ms = 100
        self.process_matched_channels(matched_map)
        self.serialize_outputs()

    def serialize_outputs(self):
        """序列化输出 M3U、TXT 及审计状态报告"""
        os.makedirs(self.output_dir, exist_ok=True)
        m3u_path = os.path.join(self.output_dir, "live_custom.m3u")
        txt_path = os.path.join(self.output_dir, "live_custom.txt")
        stat_path = os.path.join(self.output_dir, "channels_stat.json")

        # 1. 序列化 M3U
        m3u_lines = []
        epg_attr = f' x-tvg-url="{",".join(self.epg_urls)}"' if self.epg_urls else ""
        m3u_lines.append(f"#EXTM3U{epg_attr}")

        for spec in self.channels_spec:
            for idx, stream in enumerate(spec.active_streams):
                suffix = f" (备用{idx})" if idx > 0 else ""
                display_name = f"{spec.name}{suffix}"
                inf_line = (
                    f'#EXTINF:-1 tvg-id="{spec.tvg_id}" tvg-name="{spec.tvg_name}" '
                    f'tvg-logo="{spec.logo}" group-title="{spec.group_name}",{display_name}'
                )
                m3u_lines.append(inf_line)
                m3u_lines.append(stream.url)

        with open(m3u_path, "w", encoding="utf-8") as f:
            f.write("\n".join(m3u_lines) + "\n")
        logger.info(f"✅ 生成 M3U 订阅清单: {m3u_path} (频道线路条数: {len(m3u_lines) // 2})")

        # 2. 序列化 TXT (按分类分块)
        txt_lines = []
        current_grp = ""
        for spec in self.channels_spec:
            if spec.group_name != current_grp:
                if txt_lines:
                    txt_lines.append("")  # 空行分隔
                current_grp = spec.group_name
                txt_lines.append(f"{current_grp},#genre#")

            for stream in spec.active_streams:
                txt_lines.append(f"{spec.name},{stream.url}")

        with open(txt_path, "w", encoding="utf-8") as f:
            f.write("\n".join(txt_lines) + "\n")
        logger.info(f"✅ 生成 TXT 订阅清单: {txt_path}")

        # 3. 统计审计 JSON
        total_channels = len(self.channels_spec)
        active_channels = sum(1 for s in self.channels_spec if s.active_streams)
        stat = {
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "total_channels": total_channels,
            "active_channels": active_channels,
            "coverage_rate": f"{(active_channels / total_channels * 100):.1f}%" if total_channels else "0%",
            "groups": {},
        }
        for spec in self.channels_spec:
            if spec.group_name not in stat["groups"]:
                stat["groups"][spec.group_name] = []
            stat["groups"][spec.group_name].append({
                "name": spec.name,
                "active_lines": len(spec.active_streams),
                "best_ttfb_ms": spec.active_streams[0].ttfb_ms if spec.active_streams else -1,
                "sources": [s.source_name for s in spec.active_streams],
            })

        with open(stat_path, "w", encoding="utf-8") as f:
            json.dump(stat, f, indent=2, ensure_ascii=False)
        logger.info(f"✅ 生成审计统计报告: {stat_path}")

    async def compile(self):
        """执行完整编译流水线"""
        self.load_manifest()
        raw_candidates = await self.fetch_all_upstreams()
        matched_map = self.filter_and_match(raw_candidates)
        await self.probe_all_channels(matched_map)
        self.serialize_outputs()


def parse_args():
    parser = argparse.ArgumentParser(description="mytv-android 纯 IPv4 流媒体编译引擎")
    parser.add_argument(
        "--manifest",
        default="config/iptv/channels_manifest.json",
        help="频道编目与上游源配置文件路径 (默认: config/iptv/channels_manifest.json)",
    )
    parser.add_argument(
        "--output-dir",
        default="config/iptv/output",
        help="产物输出目录 (默认: config/iptv/output)",
    )
    parser.add_argument(
        "--skip-probe",
        action="store_true",
        help="跳过网络测速探活 (适用于离线测试或快速语法校验)",
    )
    parser.add_argument(
        "--max-lines",
        type=int,
        default=None,
        help="覆盖单频道最大线路输出上限 (默认使用 manifest 中的设置)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    compiler = IPTVCompiler(
        manifest_path=args.manifest,
        output_dir=args.output_dir,
        skip_probe=args.skip_probe,
        max_lines_override=args.max_lines,
    )
    try:
        asyncio.run(compiler.compile())
    except Exception as err:
        logger.error(f"❌ 编译流水线执行异常: {err}", exc_info=True)
        sys.exit(1)
