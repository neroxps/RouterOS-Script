# configuration
:local dnsStatus;
:local dnsIP [/ip dns get servers];
:local clashDns 172.16.233.2;
:local telecomDns 202.96.128.166;
:local clashForwardnRule [/ip firewall mangle find comment="Clash-out"];

# local variable
:local logTag "Clash_dns_check"
:local scriptName $logTag
# 脚本日志级别
:local logLevel "DEBUG"

# Load module
:global loadModule; if ( !any $loadModule ) do={
    do {/system script run [find name=loadModule]} on-error={:error "Script loadModule not found!"}
}

# import logger
:local logger ([ $loadModule logger init=({"logTag"=$logTag;"level"=$logLevel;}) ]->"logger")

# import Wecom
:local WecomArr [ $loadModule Wecom ]
:local WecomSend ($WecomArr->"send")
:local WecomDep ($WecomArr->"Dep")

# 微信推送标记，防止重复推送
:global "CheckDns::WecomMsg"

:set dnsStatus true;
$logger debug ("Script $scriptName starting")
:do {
    :local result [ :resolve www.google.com server=$clashDns ]
    # 如果 clashDns 获得的解析不是 fake-ip 那证明 DNS 有问题。微信推送处理。
    if ( $result in 198.18.0.0/16 ) do={
        $logger debug ("google ipaddress:$result is fake-ip.")
        if ($"CheckDns::WecomMsg" != "NOTSET") do={
            :set $"CheckDns::WecomMsg" "NOTSET";
            $WecomSend "clash dns resolution has returned to normal." Dep=$WecomDep;
        }
    } else={
        $logger error ("google ipaddress:$result is not fake-ip.")
        # 防止重复推送
        if ($"CheckDns::WecomMsg" != "noFakeIP") do={
            :set $"CheckDns::WecomMsg" "noFakeIP";
            $WecomSend "Notice! The Google IP queried is not fake-ip, please deal with it in time."  Dep=$WecomDep;
        }
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
        $logger info ("Set DNS to Clash DNS.")
        /ip dns set servers=$clashDns;
        $logger info ("set dns success");
        /ip dns cache flush; 
        /ip firewall mangle enable $clashForwardnRule;
        $logger info ("Enable Clash forwarding rules.");
        $WecomSend "Clash DNS is working!"  Dep=$WecomDep
    }
} else={
    if ([/ip dns get servers] != $telecomDns) do={
        $logger error ("Clash DNS is notwork!");
        $logger info ("Set DNS to telecom operators DNS.")
        /ip dns set servers=$telecomDns;
        /ip dns cache flush;
        /ip firewall mangle disable $clashForwardnRule;
        $logger info ("Disable Clash forwarding rules.");
        $WecomSend "Clash DNS is notwork!"  Dep=$WecomDep;
    }
}