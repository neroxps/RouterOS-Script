# configuration
:local dnsStatus;
:local dnsIP [/ip dns get servers];
:local clashDns 10.89.1.8;
:local telecomDns 202.96.128.166;
:local clashForwardnRule [/ip firewall mangle find comment="Clash-out"];

# import Module
:local logTag "Clash_dns_check"
:local scriptName $logTag
:global "Module::import"
if ( !any $"Module::import" ) do={
    do {/system script run [find name=Module]} on-error={:error "Script Module not found!"}
}
:global "Module::remove"


# 设置模块日志级别-如果需要 debug 模块请取消注释，在控制台执行脚本
:global  scriptLogLevel
:set ($scriptLogLevel->"modulesLevel"->$logTag) ($scriptLogLevel->"INFO")

:set dnsStatus true;
:do {
    :resolve www.google.com server=$clashDns;
} on-error={
    :set dnsStatus false
};
if ($dnsStatus) do={
    if ([/ip dns get servers] != $clashDns) do={
        $"Module::import" logger $scriptName
        :global logger
        $logger info ([$logTag] "Set DNS to Clash DNS.")
        /ip dns set servers=$clashDns;
        $logger info ([$logTag] "set dns success");
        /ip dns cache flush; 
        /ip firewall mangle enable $clashForwardnRule;
        $logger info ([$logTag] "Enable Clash forwarding rules.");
        $"Module::import" Wecom $scriptName
        :global "Wecom::send"
        $"Wecom::send" "Clash DNS is working!"
    }
} else={
    if ([/ip dns get servers] != $telecomDns) do={
        $"Module::import" logger $scriptName
        :global logger
        $logger error ([$logTag] "Clash DNS is notwork!");
        $logger info ([$logTag] "Set DNS to telecom operators DNS.")
        /ip dns set servers=$telecomDns;
        /ip dns cache flush;
        /ip firewall mangle disable $clashForwardnRule;
        $logger info ([$logTag] "Disable Clash forwarding rules.");
        $"Module::import" Wecom $scriptName
        :global "Wecom::send"
        $"Wecom::send" "Clash DNS is notwork!";
    }
}

$"Module::remove" Wecom $scriptName
$"Module::remove" logger $scriptName