# 可以新建定时脚本，每分钟执行一次定时修改 wan-ip 列表
# /system scheduler
# add interval=1m name=update_wan_ip on-event=update_wan_ip policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-time=startup
:local PPPOEINTERFACES [/interface pppoe-client print as-value]
:local LISTNAME "wan-ip"
if ([:len $PPPOEINTERFACES] = 0) do={
    :error "pppoe interface not found!"
}

# check ip in list
:local ifIpInList do={
    :local listname $1;
    :local ipAddress $2;
    :foreach id in=[/ip firewall address-list find where list=$listname] do={
        :local listIpAddr [/ip firewall address-list get $id address]
        if ($ipAddress = $listIpAddr) do={
            return true
        }
    }
    return false
}

:for i from=0 to=([:len $PPPOEINTERFACES] - 1) do={
    :local interfaceName ($PPPOEINTERFACES->$i->"name")
    :local currentIP [/ip address get  [find interface=$interfaceName] address]
    :set currentIP [:pick $currentIP 0 [:find $currentIP "/"]];
    if (! [$ifIpInList $LISTNAME $currentIP]) do={
        # Interface address not in the list
        if ([:len [/ip firewall address-list find where ( comment=$interfaceName list=$LISTNAME)]] = 0) do={
            :put "Add interface:$interfaceName ip:$currentIP to address-list:$LISTNAME."
            /ip firewall address-list add list=$LISTNAME address=$currentIP comment=$interfaceName
        } else={
            :put "Set interface:$interfaceName ip:$currentIP to address-list:$LISTNAME."
            /ip firewall address-list set [ find list=$LISTNAME comment=$interfaceName] address=$currentIP 
        }
    } else={
        :put "No change in interface($interfaceName) address"
    }
}