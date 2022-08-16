# 脚本依赖: Module logger 
# 脚本说明： 利用全局变量传入参数后，调用本脚本进行企业微信推送
# 可以在本脚本定义 Wecom 配置，也可以在调用处定义。

# example
# :global loadModule; if ( !any $loadModule ) do={
#     do {/system script run [find name=loadModule]} on-error={:error "Script loadModule not found!"}
# }
# :local WecomArr [ $loadModule Wecom ]
# :local WecomSend ($WecomArr->"send")
# :local WecomDep ($WecomArr->"Dep")
# $WecomSend Dep=$WecomDep "Hello World"


# 全局配置参数 CONFIG
## corpid 企业微信企业ID corpid
## corpsecret 企业微信应用 corpsecret
## agentid 企业微信应用ID agentid
## touser发送给企业微信的用户ID如 "user1" 多个用户可以这样写 {"user1";"user2"}，mikrotik 数组形式
# :local CONFIG {
#     "corpid"="Change to your corpid";
#     "corpsecret"="Change to your corpsecret";
#     "agentid"="Change to your agentid";
#     "touser"={"user1";"user2"}
# }

:local CONFIG {
    "corpid"="Change to your corpid";
    "corpsecret"="Change to your corpsecret";
    "agentid"="Change to your agentid";
    "touser"={"user1";"user2"}
}

# local variable
:local logTag "Wecom"
:local scriptName $logTag
# 脚本日志级别
:local logLevel "DEBUG"

# Load module
:global loadModule; if ( !any $loadModule ) do={
    do {/system script run [find name=loadModule]} on-error={:error "Script loadModule not found!"}
}

# import logger
:local logger ([ $loadModule logger init=({"logTag"=$logTag;"level"=$logLevel;}) ]->"logger")

# 控制是否发送企业微信开关
:global "Wecom::sendToWecom"
if ([:typeof $"Wecom::sendToWecom"] = "nothing") do={
    :global "Wecom::sendToWecom" true
    $logger debug ("WeCom notification is enable")
}


# 发送消息到企业微信
# 使用方法：
## 1. 如果在脚本中定义了全局变量 $CONFIG，可以直接发送
### $send <message text>
## 2. 如果希望临时修改企业微信接受者可以这样写
## $send <message text> touser={"user1","user2"...}
## 3. 如果希望临时修改企业微信配置文件可以通过 input 传入，参数类型是 array，或直接以参数形式传入。
### 配置优先级传入参数 > 脚本配置
### $send <message text> input={"corpid"=<$corpid>,"corpsecret"=<$corpsecret>,"agentid"=<$agentid>,"touser"={"user1","user2"...}}
### $send <message text> corpid=<$corpid> corpsecret=<$corpsecret> agentid=<$agentid> touser={"user1","user2"...}}
## 4. 支持单独定义 touser ，如某个脚本希望单独推送给特定用户。支持 string 或 array 类型
### $send <message text> touser={"user1","user2"...}}
### $send <message text> touser="user1"
## 5. 支持 Markdown 传入
### $send (#title1\n## title2) touser="user1" markdown=true
:local "send" do={
    # local variable
    :local logTag "send"
    if ( ! any $Dep ) do={ :error message=("[Wecom] [$logTag] Dep(Dependency) is not defined!") }
    :local logger ($Dep->"logger")
    :local CONFIG ($Dep->"CONFIG")
    :global "Wecom::sendToWecom"
    :local message $1
    :local config

    # subFunction
    ## 检查配置参数是否正确
    :local checkConfig do={
        :local args $1
        :local logTag "send::checkConfig"
        if ( ! any $Dep ) do={ :error message=("[Wecom] [$logTag] Dep(Dependency) is not defined!") }
        :local logger ($Dep->"logger")
        if ([:len $args] = 0) do={
            $logger ("[$logTag] args is zero!")
            return false
        }
        :foreach k,v in=$args do={
            if ( [ typeof $v ] = "nothing" ) do={
                $logger ("[$logTag] $k is not defined!")
                return false
            }
        }
        return true
    }

    # Function main
    ## 加载配置文件，参数允许传入脚本
    :local inputConfig
    $logger debug ("[$logTag] check \$input.")
    if ([:typeof $input] != "nothing") do={
        $logger ("[$logTag] Apply \$input to inputConfig.")
        :set inputConfig $input
    }
    $logger debug ("[$logTag] check incoming parameter.")
    if ( ([:typeof $inputConfig] = "nothing") && \
        ([:typeof $corpid] = "str") && \
        ([:typeof $corpsecret] = "str") && \
        ([:typeof $agentid] = "str") && \
        ([:typeof $touser] = "array") ) do={
        $logger ("[$logTag] Apply incoming parameter to inputConfig.")
        :set inputConfig {"corpid"=$corpid;"corpsecret"=$corpsecret;"agentid"=$agentid;"touser"=$touser}
    }
    $logger debug ("[$logTag] check \$inputConfig.")
    if ([$checkConfig $inputConfig Dep=$Dep]) do={
        $logger ("[$logTag] Apply incoming parameter configuration.")
        :set config $inputConfig
    }
    $logger debug ("[$logTag] check \$CONFIG")
    if ( ([typeof $config] = "nothing") && ([$checkConfig $CONFIG Dep=$Dep])) do={
        $logger ("[$logTag] Apply global variable configuration.")
        :set config $CONFIG
        # touser 以传入为准作为覆盖
        if ([:len $touser] > 0)  do={
            # touser 是数组，作为参数传入，覆盖$config->touser 配置
            if ([typeof $touser] = "array") do={
                :set ($config->"touser") $touser
            }
            # touser 是字符串作为参数传入，覆盖$config->touser 配置
            if ([typeof $touser] = "str") do={
                :set ($config->"touser") ("\"$touser\"")
            }
        }
    }
    if ([typeof $config] = "nothing") do={
        $logger error ("[$logTag] config file not found.")
        :error ("Ues:\n\$\"Wecom::send\" <message> [corpid=\"<corpid>\" corpsecret=\"<corpsecret>\" agentid=\"<agentid>\" touser=\"<touser>\"]")
    }
    # 处理 touser ，将 array 转为 json string
    if ([typeof ($config->"touser")] = "array") do={
        $logger debug ("[$logTag] Touser array converted to json string.")
        :local string ""
        :for i from=0 to=([:len ($config->"touser")] - 1) do={
            :set string ($string . "\"$($config->"touser"->$i)\",")
        }
        :set string [:pick $string 0 ([:len $string] - 1)];
        :set ($config->"touser") $string;
    }
    :local configStr [:tostr $config;]
    $logger debug ("[$logTag] config:$configStr, message:$message")
    if ($"Wecom::sendToWecom" = true) do={
        $logger debug ("[$logTag] WeCom push start.")
        :local wecomGetTokenUrl "https://qyapi.weixin.qq.com/cgi-bin/gettoken\?corpid=$($config->"corpid")&corpsecret=$($config->"corpsecret")";
        :local wecomData ([/tool fetch url=$wecomGetTokenUrl mode=https output=user as-value] ->"data");
        :local tokenStartPos ([tonum [:find $wecomData "token" -1]]+8);
        :local tokenEndPos ($tokenStartPos+214);
        :local token [:pick $wecomData $tokenStartPos $tokenEndPos];
        :local wecomSendUrl ("https://qyapi.weixin.qq.com/cgi-bin/message/send\?access_token=$token");
        :local msg "[From MikroTik] $message"
        :local payload "{\"touser\":$($config->"touser"),\"msgtype\":\"text\",\"agentid\":$($config->"agentid"),\"text\":{\"content\":\"$msg\"},\"safe\":0}";
        if ($markdown = "true") do={
            :set msg $message
            set payload "{\"touser\":$($config->"touser"),\"msgtype\":\"markdown\",\"agentid\":$($config->"agentid"),\"markdown\":{\"content\":\"$msg\"},\"safe\":0}";
        }
        :local result [/tool fetch url=$wecomSendUrl mode=https output=user http-method=post http-data=$payload as-value];
        :local resultStr [:tostr $result;]
        $logger debug ("[$logTag] Wecom api push result:$resultStr")
        :if ($result->"status" != "finished") do={
            $logger error ("[$logTag] post failed, result=" . $result->"data")
        }
    } else={
        $logger debug ("[$logTag] Wecom::sendToWecom is false.")
    }
}

# 逐行组装推送消息
## 必须输入参数：
## - msgArr 数组形式
## - msg 传入的字符串单行
## 返回 msg 新数组
:local setMessage do={
    :local logTag "setMessage"
    :local msgArray $msgArr
    if ( ! any $Dep ) do={ :error message=("[Wecom] [$logTag] Dep(Dependency) is not defined!") }
    :local logger ($Dep->"logger")
    if (! any $msgArr) do={ :error message=("[Wecom] [$logTag] msgArr is not defined!") }
    if (! any $msg) do={
        $logger debug ("[$logTag] msg is not defined!")
        set (msgArray->[:len $msgArray]) ""
    }
    

}

return {
    "moduleName"="Wecom";
    "send"=$send;
    "Dep"={
        "CONFIG"=$CONFIG;
        "logger"=$logger;
    }
}