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

为了解决这个问题，所有模块脚本最终都会将自己作用域的方法放入 Array 内，最终将 Array return 到当前作用域，实现加载任务。

### loadModule 介绍
引入脚本模块，脚本最后必须将函数代码放入 array 中，然后通过 return array 传递给当前脚本使用。

#### 模块加载 loadModule
**使用方法：**
```
:local logger ([ $loadModule logger init=({"logTag"=$logTag;"level"=$logLevel;}) ]->"logger")
```
**参数：**
  - **init**: 作为数组传入 loadModule ，如模块发现加载模块有 init 方法，则调用它，范例是初始化当前 logger 

未完待续.....