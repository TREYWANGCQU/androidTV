# scripts/iptv/test_compiler.py
"""
mytv-android 纯 IPv4 流媒体编译引擎单元测试与门禁验证脚本
"""

import json
import os
import sys
import unittest

# 将当前目录与项目根目录加入 sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from scripts.iptv.compiler import ContentParser, IPTVCompiler, IPv4Gate


class TestIPTVCompiler(unittest.TestCase):
    """测试编译引擎各关键门禁与解析能力"""

    def test_manifest_integrity(self):
        """测试 channels_manifest.json 语法完整性与必要字段"""
        manifest_path = "config/iptv/channels_manifest.json"
        self.assertTrue(os.path.exists(manifest_path), f"配置文件不存在: {manifest_path}")

        with open(manifest_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertIn("settings", data)
        self.assertIn("groups", data)
        self.assertIn("upstream_sources", data)

        settings = data["settings"]
        self.assertTrue(settings.get("ipv4_only"), "必须显式开启 ipv4_only")
        self.assertGreater(len(data["groups"]), 0, "必须声明至少一个频道分组")

        total_channels = sum(len(g.get("channels", [])) for g in data["groups"])
        self.assertGreater(total_channels, 20, f"预置频道数过少 ({total_channels})，需覆盖央视与主流卫视")

    def test_ipv4_gate_strict(self):
        """测试 IPv4 门禁对各类协议与字面量地址的过滤有效性"""
        # 1. 明显的 IPv6 字面量地址必须全部拦截
        ipv6_test_cases = [
            "http://[2409:8087:1a01:df::4077]/live/cctv1.m3u8",
            "http://[2408:873d:101:100::1]:8080/live.m3u8",
            "https://[2001:da8::1]/stream.m3u8",
            "http://[fe80::1]/test.m3u8",
            "ftp://[::1]/stream",
            "not_a_valid_url",
            "",
        ]
        for url in ipv6_test_cases:
            self.assertFalse(IPv4Gate.is_ipv4_strict(url), f"未能正确拦截 IPv6 或非法链接: {url}")

        # 2. 合法的字面量 IPv4 地址必须放行
        ipv4_test_cases = [
            "http://111.13.134.20/live/cctv1.m3u8",
            "http://183.232.126.10:8080/live/stream.m3u8",
            "http://127.0.0.1:8000/test.m3u8",
        ]
        for url in ipv4_test_cases:
            self.assertTrue(IPv4Gate.is_ipv4_strict(url), f"合法的纯 IPv4 地址被错误误杀: {url}")

    def test_content_parser_m3u(self):
        """测试 M3U8 解析器与元数据属性提取"""
        sample_m3u = """#EXTM3U x-tvg-url="https://live.fanmingming.com/e.xml"
#EXTINF:-1 tvg-id="CCTV1" tvg-name="CCTV-1 综合" tvg-logo="https://live.fanmingming.com/tv/CCTV1.png" group-title="央视频道",CCTV-1 综合
http://111.13.134.20/live/cctv1.m3u8
#EXTINF:-1 tvg-id="Hunan" tvg-name="湖南卫视" group-title="卫视频道",湖南卫视高清
http://183.232.126.10/live/hunan.m3u8
"""
        parsed = ContentParser.parse_m3u(sample_m3u, "TestM3U")
        self.assertEqual(len(parsed), 2)
        self.assertEqual(parsed[0].raw_title, "CCTV-1 综合")
        self.assertEqual(parsed[0].tvg_id, "CCTV1")
        self.assertEqual(parsed[0].url, "http://111.13.134.20/live/cctv1.m3u8")
        self.assertEqual(parsed[1].raw_title, "湖南卫视高清")
        self.assertEqual(parsed[1].group_title, "卫视频道")

    def test_content_parser_txt(self):
        """测试 TXT 格式解析器"""
        sample_txt = """央视频道,#genre#
CCTV-1,http://111.13.134.20/live/cctv1.m3u8
CCTV-2,http://111.13.134.20/live/cctv2.m3u8

卫视频道,#genre#
湖南卫视,http://183.232.126.10/live/hunan.m3u8
"""
        parsed = ContentParser.parse_txt(sample_txt, "TestTXT")
        self.assertEqual(len(parsed), 3)
        self.assertEqual(parsed[0].group_title, "央视频道")
        self.assertEqual(parsed[0].raw_title, "CCTV-1")
        self.assertEqual(parsed[2].group_title, "卫视频道")
        self.assertEqual(parsed[2].raw_title, "湖南卫视")

    def test_offline_compiler_pipeline(self):
        """测试离线编译流水线与产物输出格式"""
        manifest_path = "config/iptv/channels_manifest.json"
        test_output_dir = "config/iptv/test_output"

        compiler = IPTVCompiler(
            manifest_path=manifest_path,
            output_dir=test_output_dir,
            skip_probe=True,
            max_lines_override=2,
        )
        compiler.load_manifest()

        # 模拟一批样本候选源
        mock_candidates = [
            ContentParser.parse_m3u(
                """#EXTM3U
#EXTINF:-1,CCTV-1 综合
http://111.13.134.20/live/cctv1_line1.m3u8
#EXTINF:-1,CCTV1 综合 HD
http://111.13.134.21/live/cctv1_line2.m3u8
#EXTINF:-1,湖南卫视
http://183.232.126.10/live/hunan.m3u8
#EXTINF:-1,凤凰卫视中文台
http://103.172.187.30/live/fhzw.m3u8
#EXTINF:-1,非法IPv6央视源
http://[2409:8087::1]/live/cctv1.m3u8
""",
                "MockSource",
            )
        ][0]

        matched = compiler.filter_and_match(mock_candidates)
        self.assertIn("CCTV-1 综合", matched)
        self.assertEqual(len(matched["CCTV-1 综合"]), 2, "应匹配 2 条有效 IPv4 CCTV-1 线路")

        # 验证 IPv6 假源已被阻断
        all_matched_urls = [c.url for streams in matched.values() for c in streams]
        self.assertNotIn("http://[2409:8087::1]/live/cctv1.m3u8", all_matched_urls)

        # 运行离线编译并序列化产物
        compiler.compile_offline(mock_candidates)

        # 验证产物文件是否存在
        m3u_file = os.path.join(test_output_dir, "live_custom.m3u")
        txt_file = os.path.join(test_output_dir, "live_custom.txt")
        stat_file = os.path.join(test_output_dir, "channels_stat.json")

        self.assertTrue(os.path.exists(m3u_file))
        self.assertTrue(os.path.exists(txt_file))
        self.assertTrue(os.path.exists(stat_file))

        with open(m3u_file, "r", encoding="utf-8") as f:
            m3u_content = f.read()
            self.assertTrue(m3u_content.startswith("#EXTM3U"))
            self.assertIn("CCTV-1 综合", m3u_content)
            self.assertNotIn("[2409:", m3u_content)

        with open(txt_file, "r", encoding="utf-8") as f:
            txt_content = f.read()
            self.assertIn("央视频道,#genre#", txt_content)
            self.assertIn("CCTV-1 综合,", txt_content)


if __name__ == "__main__":
    unittest.main()
