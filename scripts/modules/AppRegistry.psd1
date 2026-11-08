# scripts/modules/AppRegistry.psd1
@{
    Apps = @(
        @{
            Id          = 'BBLL'
            Name        = 'BlBl (BBLL)'
            Type        = 'github'
            Repo        = 'xiaye13579/BBLL'
            AssetFilter = '.*release.*\.apk$'
            Exclude     = '.*debug.*'
            TargetFile  = 'BBLL-latest.apk'
            Description = '哔哩哔哩 TV/Pad 开源第三方客户端'
        },
        @{
            Id          = 'TizenTube'
            Name        = 'TizenTube / SmartTube'
            Type        = 'github'
            Repo        = 'yuliskov/SmartTube'
            FallbackRepo= 'reisxd/TizenTubeCobalt'
            AssetFilter = '.*(arm|release|Cobalt|stable).*\.apk$'
            Exclude     = '.*(x86|beta).*'
            TargetFile  = 'TizenTube-latest.apk'
            Description = 'YouTube TV 核心去广告客户端'
        },
        @{
            Id          = 'TVBox'
            Name        = 'TVBox (FongMi)'
            Type        = 'github'
            Repo        = 'FongMi/Release'
            FallbackRepo= 'q215613905/TVBoxOS'
            AssetFilter = '.*(leanback|java).*\.apk$'
            Exclude     = '.*mobile.*'
            TargetFile  = 'TVBox-latest.apk'
            Description = '开源聚合点播/直播播放器'
        },
        @{
            Id          = 'mytv'
            Name        = 'mytv-android'
            Type        = 'github'
            Repo        = 'mytv-android/mytv-android'
            AssetFilter = '.*release.*\.apk$'
            Exclude     = '.*debug.*'
            TargetFile  = 'mytv-latest.apk'
            Description = '极简电视直播 IPTV 客户端'
        },
        @{
            Id          = 'EmotnLauncher'
            Name        = 'Emotn Launcher'
            Type        = 'direct'
            Url         = 'https://app.emotn.com/download/app'
            FallbackUrls= @(
                'https://cdn.emotn.com/apk/EmotnUI.apk'
            )
            TargetFile  = 'EmotnLauncher-latest.apk'
            Description = '长辈友好型纯净电视桌面'
        }
    )
    Mirrors = @(
        'https://ghproxy.net/',
        'https://mirror.ghproxy.com/',
        'https://kkgithub.com/'
    )
    MinApkSizeBytes = 5242880
}

