# 自用 RouterOS 脚本库
[toc]
## Module.src 加载其他依赖脚本模块

### 为何要设计那么复杂的模块？

我在编写和调试脚本的时候，经常遇到这个功能和其他脚本功能重复的情况，例如脚本日志控制 **logger**，当我修改它的时候，其他脚本依赖又需要重新修改。

为了解决这个需求，我尝试使用 Mikrotik 推荐的从 A 脚本中引入为 B 脚本。
>https://wiki.mikrotik.com/wiki/Manual:Scripting

**添加脚本**
```
#add script
 /system script add name=myScript source=":put \"Hello $myVar !\""
```

**在另一个脚本里引入它**
```
:global myFunc [:parse [/system script get myScript source]]
$myFunc myVar=world

output:
Hello world !
```

但是这种方案有个致命缺点就是一跑脚本，`/system script environment` 里面就会有一大堆全局变量，脚本少还行，如果多的情况下会遇到例如：
- 不同脚本的全局环境变量重名覆盖导致异常
- 过多的环境变量引入内存中，导致一些小内存机器因为加载脚本太多，内存紧张
- 有些脚本环境变量不会回收

可能有人会说，你可以把脚本加载到 **local** 上，就不会有问题了啊。

对！的确是可以的，但 **local** 的作用域仅限于当前的程序块 `[]`，如果 Func::A 需要调用 Func::B 呢么你 **local** 就不行了，需要在把 Func::B 定义为全局变量，在调用结束后还得回收这个 Func::B。

综上所述，我设计了一个脚本模块管理工具，写代码不需要考虑全局环境变量重名问题。也不需要考虑回收问题。脚本内所有 Function 都是全局变量，脚本的任何 Function 都可以任意调用。只需要在脚本结束时候 `$"Module::remove" <moduleName> <scriptName>` 就可以将这个模块依赖从全局变量中卸载掉。

### Module 介绍
#### 模块命名规则
- 模块名字以英文字母和阿拉伯数字
- 模块内定义所有全局变量均采用 :global `[ModuleName]::[variableName]` 方式命名，以便卸载模块时候统一卸载
- 模块脚本中如果调用 logger 记录日志，logTag 必须遵循 `[ModuleName]::[function]` 方式命名，否则 logger 日志模块无法识别日志等级。

#### 模块加载 Module::import
**使用方法：**
```
:global "Module::import"
$"Module::import" <moduleName> <scriptName> [reload=true]
```
**参数：**
  - **moduleName**: 模块名字，如 logger
  - **scriptName**: 当前脚本名字，如 DDNS_dynu，作用于模块锁定
  - **reload**: 布尔值，覆盖之前加载的模块，如 `[true|false]`

#### 卸载模块 Module::remove
**使用方法：**
```
:global "Module::remove"
$"Module::remove" <moduleName> <scriptName> [force=true]
```
参数：
  - **moduleName**: 模块名字，如 logger
  - **scriptName**: 当前脚本名字，如 DDNS_dynu，作用于模块解锁
  - **force**: 不管是否锁定一律卸载，请谨慎使用

**模块卸载逻辑**
模块卸载的时候会查找所有环境变量的名字，以模块开头的环境变量一律删除。关键代码如下:
```
:local regex ("^$moduleName")
system script environment remove [/system script environment find where name~$regex]
```

#### 模块锁 Module::lock

为了防止脚本结束卸载模块时候，该模块正被另一个脚本调用，导致另一个脚本正在调用模块失败，所以采取一个环境变量记录当前加载模块的脚本名字，在脚本卸载模块的时候，从此环境变量的模块名字中删除自己的脚本名称。

```
:global "Module::lock" {
"<moduleName>"="|[<scriptName>|static]|<scriptName1>|"; # 如果设置为 static，模块将不会被卸载 
}
```
## logger.rsc 日志记录器

相信写过 Mikrotik 脚本都体会到，某些脚本执行错误了，如果没有使用 do={} on-error={} 这种方式来定义的代码块，一旦出现错误，就不会执行下去。有些时候需要调试代码或者记录脚本执行过程方便调试，使用 **put** 虽然可以打印，但并不能讲日志分级别记录起来，**log**虽然也可以分类记录，但又不能打印在前台调试，不知道为何，我使用 **debug** 类别打印的日志没有输出到控制台。

综上所述，我参考 python 的 logger 设置了一个简单的日志记录器。

### logger 使用方法

参数：
- **第一参数**：日志级别
- **第二参数**：字符串
  - **日志内容**：必须以 `[scriptName]` 形式开头，全局变量 `scriptLogLevel` 会以当前脚本名字识别设置的日志级别，如果没设置则以默认级别打印，默认是 WARNING
> 日志内容那块还没想好怎么设计，好像不太合理，如果用多一个参数感觉又很麻烦，暂时先这样。
```
$"Module::import" logger $scriptName
:global logger
$logger <info message> # 只打印不记录日志
$logger [info|warning|error|debug] "[scriptName]<log message>"
```

## JsonParse.rsc json 解析器

这个 json 解析器是大神写的，我没有修改什么，只是让他符合我 Module 运行规则而已，好调用完清理掉，否则一大堆 env 在 script 不喜欢。

[https://github.com/Winand/mikrotik-json-parser](https://github.com/Winand/mikrotik-json-parser)

### JsonParse 使用方法

```
$"Module::import" JsonParse $scriptName
:global "JsonParse::parseOut"
:global "JsonParse::parse"
:global "JsonParse::jsonIn"
:set "JsonParse::jsonIn" "{"abc":"def"}"
:set "JsonParse::parseOut" [$"JsonParse::parse"]
:put ($"JsonParse::parseOut"->"abc")
# output def
```


## Dynu.src Dynu 域名服务商 DDNS 更新

Mikrotik 本身有 Cloud 服务，能够提供 DDNS 服务，它的 DDNS 服务只能推送路由本身的 IP 地址，IPv4 的时候还没什么问题，因为都是 NAT 上网。但 IPv6 无法自定义上传的后缀，所以我需要一个支持 TTL 60秒的 DDNS 域名服务商。而 Dynu 正符合我的需求。

### Dynu 使用方法
传入变量：
  - apiKey: Dynu 的 ApiKey 由此获得[DynuApiKey](https://www.dynu.com/ControlPanel/APICredentials)
  - domainId: 通过 Linux 命令获取你域名的 id, ` curl -X GET https://api.dynu.com/v2/dns -H "accept: application/json" -H "API-Key: <这里写你的 APIKEY>"`
  - domainName: 你获得的 ddns 域名
返回值，返回的是一个 Array：
  - result：布尔值，确认推送状态
  - logMessage：错误日志内容，如果有错误则返回

```
$"Module::import" Dynu $scriptName
:global "Dynu::push"
$"Dynu::push" <apiKey=$apiKey> <domainId=$domainId> <domainName=$domainName> <ipv4Address=$ipv4Address> [ipv6Address=$ipv6Address]
:local pushResult [$"Dynu::push" apiKey="apiKey" domainId="domainId" domainName="domainName" ipv4Address=$ipv4Address ipv6Address=$ipv6Address]
if (! ($pushResult->"result")) do={
    :error message=($pushResult->"logMessage")
}
```

## DDNS 根据自己需求将 IP 地址更新至各域名服务商

一开始只是写成面条脚本，只能更新 Dynu 也只能更新一个地址，后来几次改写，成了现在这个样子。
原理先通过 PPPOE 接口的名字获取当前接口的 IPv4 地址和 IPv6 前缀，然后推送至启用的DDNS 服务，目前我只做了 Dynu，最后对接企业微信推送。将 DDNS 结果推送到企业微信应用上。

### DDNS 脚本使用方法

- DDNS::Config 全局 DDNS 服务商配置
  - ddnsServices: 数组，是否启用某个 ddns 服务，enable 则启用，其余字符串一律不启用
  - Dynu 配置信息
      - apiKey:访问以下网站获取 dynuApiKey https://www.dynu.com/en-US/ControlPanel/APICredentials
      - domainId:通过以下 Linux 命令获取你域名的 id
        - `curl -X GET https://api.dynu.com/v2/dns -H "accept: application/json" -H "API-Key: <这里写你的 APIKEY>"`
      - domainName:就是你获得的 ddns 域名
  - pubyun 配置信息（该服务商不支持 ipv6）
      - user：注册用户名
      - password： 密码
      - domain：DDNS 域名

  - logLevel: 脚本日志级别
    - `:local logLevel "DEBUG"`
    - useIPv6: 是否使用 IPV6
      - `:local useIPv6 true`
  - ipv6Suffix: 设置需要对外服务器 IPV6 主机位
    - 例如你主机获取到的公网IPV6是 <240e:fb2:fff0:1f20:42d:6dff:fbf3:f2e2/64> 那么这里就写 “42d:6dff:fbf3:f2e2”
    - `:local ipv6Suffix "<ipv6Suffix>"`
  - isAddToAddressList: 是否把 ip 地址添加到防火墙 Address-list中，方便做一些防火墙策略，例如 nat loopback
    - `:local isAddToAddressList true`
  - ipv4Comment\ipv6Comment: 可选，设置 Address-list 的 comment
    - `:local ipv6Comment "wan-ipv6"`
    - `:local ipv4Comment "wan-ip"`

  - 如果有多个 pppoe 请指定接口名字,如果希望脚本自动获取请留空即可
# :local pppoeInterfaceName "<pppoe interface name>"

```
# DDNS::Config 全局 DDNS 服务商配置
    # ddnsServices: 数组，是否启用某个 ddns 服务，enable 则启用，其余字符串一律不启用
    # Dynu 配置信息
        # apiKey:访问以下网站获取 dynuApiKey https://www.dynu.com/en-US/ControlPanel/APICredentials
        # domainId:通过以下 Linux 命令获取你域名的 id
        #    curl -X GET https://api.dynu.com/v2/dns -H "accept: application/json" -H "API-Key: <这里写你的 APIKEY>"
        # domainName:就是你获得的 ddns 域名
    # pubyun 配置信息（该服务商不支持 ipv6）
        # user：注册用户名
        # password： 密码
        # domain：DDNS 域名
:global "DDNS::Config" {
    "ddnsServices"={
        "dynu"="enable";
        "pubyun"="disable"
    };
    "dynu"={
        "apiKey"="<apiKey>";
        "domainId"="<domainId>";
        "domainName"="<domainName>";
    };
    "pubyun"={
        "user"="<yourUserName>";
        "password"="<yourPassword>";
        "domain"="<yourDomain>"
    };
}

# 脚本日志级别
:local logLevel "DEBUG"
# 是否使用 IPV6
:local useIPv6 true
# 这是你需要对外服务器 IPV6 主机位
## 例如你主机获取到的公网IPV6是 <240e:fb2:fff0:1f20:42d:6dff:fbf3:f2e2/64>
## 那么这里就写 “42d:6dff:fbf3:f2e2”
:local ipv6Suffix "<ipv6Suffix>"
# 是否把 ip 地址添加到防火墙 Address-list中，方便做一些防火墙策略，例如 nat loopback
:local isAddToAddressList true
# 可选，设置 Address-list 的 comment
:local ipv6Comment "wan-ipv6"
:local ipv4Comment "wan-ip"

# 如果有多个 pppoe 请指定接口名字,如果希望脚本自动获取请留空即可
# :local pppoeInterfaceName "<pppoe interface name>"
```