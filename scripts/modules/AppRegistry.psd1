# scripts/modules/AppRegistry.psd1
@{
    Apps            = @(
        @{
            Id           = 'BT'
            Name         = 'Bilibili TV (BT)'
            Type         = 'github'
            Repo         = 'chinasoul/BT'
            FallbackRepo = 'swyefun/BBLLV5'
            AssetFilter  = '.*universal\.apk$'
            Exclude      = '.*api19.*'
            TargetFile   = 'BT-latest.apk'
            Description  = '哔哩哔哩 TV 原生遥控开源客户端'
        },
        @{
            Id           = 'TizenTube'
            Name         = 'TizenTube Cobalt'
            Type         = 'github'
            Repo         = 'reisxd/TizenTubeCobalt'
            FallbackRepo = 'yuliskov/SmartTube'
            AssetFilter  = '.*(Cobalt|universal).*\.apk$'
            Exclude      = '.*(x86).*'
            TargetFile   = 'TizenTube-latest.apk'
            Description  = 'YouTube TV 核心去广告客户端'
        },
        @{
            Id           = 'TVBox'
            Name         = 'TVBox (FongMi)'
            Type         = 'github'
            Repo         = 'FongMi/Release'
            FallbackRepo = 'q215613905/TVBoxOSCRelease'
            AssetFilter  = '.*(leanback|java).*\.apk$'
            Exclude      = '.*mobile.*'
            TargetFile   = 'TVBox-latest.apk'
            Description  = '开源聚合点播/直播播放器'
        },
        @{
            Id          = 'mytv'
            Name        = 'mytv-android'
            Type        = 'github'
            Repo        = 'mytv-android/mytv-android'
            AssetFilter = '.*mytv-android-tv.*(all|arm64-v8a).*original.*\.apk$'
            Exclude     = '.*(disguised|x5offline|x86).*'
            TargetFile  = 'mytv-latest.apk'
            Description = '极简电视直播 IPTV 客户端'
        },
        @{
            Id           = 'EmotnLauncher'
            Name         = 'Emotn Launcher'
            Type         = 'direct'
            Url          = 'https://zmautoapp.dangsfly.com/20260711/6a51fff5b0db3.apke8f2.apk'
            FallbackUrls = @(
                'https://cdn.emotn.com/apk/EmotnUI.apk'
            )
            TargetFile   = 'EmotnLauncher-latest.apk'
            Description  = '长辈友好型纯净电视桌面'
        }
    )
    Mirrors         = @(
        'https://ghproxy.net/',
        'https://mirror.ghproxy.com/',
        'https://kkgithub.com/'
    )
    MinApkSizeBytes = 2097152
}
