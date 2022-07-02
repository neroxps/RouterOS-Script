# 流量阈值 这里是 200Kbps
:local trafficThreshold 20480
# 监控的IP地址
:local trafficIpAddress "10.89.2.1"
:local TRUE 1
:local FALSE 0
:global "nvr::nvrRemoteLink";

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
:local count [$getThresholdExceedCount IpAddress=$trafficIpAddress threshold=$trafficThreshold]

# 连续检查如果结果为真则输出真
if ($count > 0) do={
    if ($"nvr::nvrRemoteLink" != $TRUE) do={
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