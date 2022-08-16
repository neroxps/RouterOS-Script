# Load Module
## 引入脚本模块，脚本最后必须将函数代码放入 array 中，然后通过 return array 传递给当前脚本使用。
## 代替之前 Module 脚本
:global loadModule do={
    :local MODULENAME 
    if ( any $moduleName ) do={
        :set $MODULENAME $moduleName
    } else={
        if ( any $1 ) do={
            :set $MODULENAME $1
        } else={
            :put ("[loadModule] error moduleName not defined.")
            return false
        }
    }
    :local module [:parse [/system script get $MODULENAME source]]
    :set module [ $module ]
    :local name ($module->"moduleName")
    if ( $name != $MODULENAME ) do={
        :put ("[error] [loadModule] moduleName:$name, inputName:$MODULENAME ")
        :put ("[error] [loadModule] Loading module does not meet expectations.")
        return false
    }
    if ( any ($module->"init")) do={
        :local scriptInit ($module->"init")
        return [ $scriptInit init=$init ]
    }
    return $module
}