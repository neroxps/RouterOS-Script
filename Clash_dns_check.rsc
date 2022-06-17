# configuration
:local dnsStatus;
:local dnsIP [/ip dns get servers];
:local clashDns 172.16.233.2;
:local telecomDns 202.96.128.166;
:local clashForwardnRule [/ip firewall mangle find comment="Clash-out"];

# import Module
:local logTag "check_dns"
:local scriptName $logTag
:global "Module::import"
if ( !any $"Module::import" ) do={
    do {/system script run [find name=Module]} on-error={:error "Script Module not found!"}
}
:global "Module::remove"

# import logger
$"Module::import" logger $scriptName
:global logger

# import Wecom
$"Module::import" Wecom $scriptName
:global "Wecom::send"

# 设置模块日志级别-如果需要 debug 模块请取消注释，在控制台执行脚本
:global  scriptLogLevel
:set ($scriptLogLevel->"modulesLevel"->$logTag) ($scriptLogLevel->"INFO")

:set dnsStatus true;
$logger ("[$logTag] Script $scriptName starting")
:do {
    :local result [ :resolve www.google.com server=$clashDns ]
    # 如果 clashDns 获得的解析不是 fake-ip 那证明 DNS 有问题。微信推送处理。
    if ( $result in 198.18.0.0/16 ) do={
        $logger ("[$logTag] google ipaddress:$result is fake-ip.")
    } else={
        $logger error ("[$logTag] google ipaddress:$result is not fake-ip.")
        $"Wecom::send" "Notice! The Google IP queried is not fake-ip, please deal with it in time.";
    };
} on-error={
   :set dnsStatus false
}

# 检查国内站点 DNS 解析，如果解析不了，证明 coredns 挂了。
:do {
    :local result [ :resolve www.baidu.com server=$clashDns ]
} on-error={
   :set dnsStatus false
}

if ($dnsStatus) do={
    if ([/ip dns get servers] != $clashDns) do={
        $logger info ("[$logTag] Set DNS to Clash DNS.")
        /ip dns set servers=$clashDns;
        $logger info ("[$logTag] set dns success");
        /ip dns cache flush; 
        /ip firewall mangle enable $clashForwardnRule;
        $logger info ("[$logTag] Enable Clash forwarding rules.");
        $"Wecom::send" "Clash DNS is working!"
    }
} else={
    if ([/ip dns get servers] != $telecomDns) do={
        $logger error ("[$logTag] Clash DNS is notwork!");
        $logger info ("[$logTag] Set DNS to telecom operators DNS.")
        /ip dns set servers=$telecomDns;
        /ip dns cache flush;
        /ip firewall mangle disable $clashForwardnRule;
        $logger info ("[$logTag] Disable Clash forwarding rules.");
        $"Wecom::send" "Clash DNS is notwork!";
    }
}

$"Module::remove" Wecom $scriptName
$"Module::remove" logger $scriptName