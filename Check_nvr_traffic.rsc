# 请手动添加添加 firware L7 协议识别
## /ip firewall layer7-protocol add name=ezviz regexp="^.+(IMKH|EzNz).+"
## /ip firewall add action=accept chain=forward comment=ezviz layer7-protocol=ezviz log-prefix=ezviz src-address=<这里写你的NVRIP地址>

# 流量阈值 这里是 200Kbps
:local trafficThreshold 20240
# 监控的IP地址
:local trafficIpAddress "10.89.2.1"
:local TRUE 1
:local FALSE 0
:global "nvr::nvrRemoteLink";
:local trafficCount

# 获取符合流量数
:local getThresholdExceedCount do={
    :local count
    :do {
    set count [/ip firewall connection print count-only where ( src-address ~ $IpAddress orig-rate>$threshold)]
    } on-error={
        return 0
    }
    return $count
}

# 通过防火墙L7流量识别读取规则识别数量来判断
:local checkFirwareCount do={
    :local count
    :do {
        set count {[/ip firewall filter get [/ip firewall filter find comment="ezviz"]]->"packets"}
        # 重置防火墙L7流量识别计数器
        /ip firewall filter reset-counters [/ip firewall filter find comment="ezviz"]
    } on-error={
        return 0
    }
    return $count
}

:local count [$checkFirwareCount]

# 连续检查如果结果为真则输出真
if ($count > 0) do={
    :set trafficCount [$getThresholdExceedCount IpAddress=$trafficIpAddress threshold=$trafficThreshold]
    if (($"nvr::nvrRemoteLink" != $TRUE) && ($trafficCount > 0)) do={
        :put "on"
        /iot mqtt publish broker=hass topic=/ros/nvrRemoteLink message="{\"state\":\"ON\"}"
        :set "nvr::nvrRemoteLink" $TRUE
    }
} else={
    if ($"nvr::nvrRemoteLink" != $FALSE) do={
        :put "off"
        /iot mqtt publish broker=hass topic=/ros/nvrRemoteLink message="{\"state\":\"OFF\"}"
        :set "nvr::nvrRemoteLink" $FALSE
    }
}