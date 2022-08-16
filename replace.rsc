# 关键字替换
## 例如 "abc%%% test %%%ghi" 替换为 abcdefghi
## $replace string=$string keyWord="%%% test %%%" value=def
## $replace string=$string startKey="%%%" endKey="%%%" value=def
## $replace string=$string key="%%%" value=def
## 必须传入参数:
## - string: 需要处理的字符串
## - keyWord: 全字匹配，如输入 {{{ test }}}
## - key: start 和 end 都是一样的话，就传入这个参数即可如: %%
## - startKey: 包裹替换字符的开始关键字，如:{{{ ,如果 key 配置了，此项不生效
## - endKey: 包裹替换字符的结束关键字，如:}}} ,如果 key 配置了，此项不生效
## - value: 替换的内容
:local replace do={
    :local result
    :local char
    :local keywordRanges
    :local pos 0
    :local maxPos [:len $string]
    if ( ! any $string ) do={ :error ("string is not defined!") }
    if ( (! any $key) && ((! any $startKey) || (! any $endKey)) && (! any $keyWord ) ) do={
        :error ("error [replace] key or startKey or endKey or keyWord is not defined!") 
    }
    if ( ! any $value ) do={ :error ("error [replace] value is not defined!") }

    # 查找关键字范围
    ## 必须传入参数:
    ## - string: 需要处理的字符串
    ## - keyWord: 全字匹配，如输入 {{{ test }}}
    ## - key: start 和 end 都是一样的话，就传入这个参数即可如: %%
    ## - startKey: 包裹替换字符的开始关键字，如:{{{
    ## - endKey: 包裹替换字符的结束关键字，如:}}}
    ## 可选参数:
    ## - startPos: 从哪里开始查找，如未定义默认为 0
    :local findKeywordRanges do={
        :local start 0
        :local end
        :local length
        :local type
        :local ranges {
            "startPos"=-1;
            "endPos"=-1;
            "length"=0;
            "found"=false;
        }
        if ( any $startPos ) do={ :set start $startPos }
        if ( any $keyWord ) do={ :set type "keyWord" }
        if ( any $key ) do={ :set type "key" }
        if ( (any $startKey) && (any $endKey) ) do={ :set type "startAndEndKey" }
        do {
            if ( $type = "keyWord" ) do={
                :set length [ :len $keyWord ]
                :set start [ find $string $keyWord $start ]
                :set end ( $start + $length )
            }
            if ( $type = "key" ) do={
                :set start [ find $string $key $start ]
                :set end [ find $string $key $start ]
                :set length ( [:len $key] + ($end - $start) )
                :set end ( $start + $length )
            }
            if ( $type = "startAndEndKey" ) do={
                :set start [ find $string $startKey $start ]
                :set end [ find $string $endKey $start ]
                :set length ( [:len $endKey] + ($end - $start) )
                :set end ( $start + $length )
            }
        } on-error={
            :put ("[error] [findKeywordRanges] An error occurred while searching for a keyword.")
            return $ranges
        }
        if ( any $start and any $end ) do={
            if ( ( $start >= 0 ) && ( $end > 0 ) ) do={
                :set ranges {
                    "startPos"=$start;
                    "endPos"=$end;
                    "length"=$length
                    "found"=true;
                }
            }
        }
        return $ranges
    }

    # 查找第一个关键字
    :set keywordRanges [ 
        $findKeywordRanges \
            string=$string \
            keyWord=$keyWord \
            key=$key \
            startKey=$startKey \
            endKey=$endKey
    ]
    # 找不到关键字，返回原字符串
    if ( ($keywordRanges->"found") = false ) do={
         if ( $debug = true) do={ :put ("[debug] [replace] No matching string found.") }
        return $string
    }
    # 循环查找字符串
    while ( ($keywordRanges->"found") = true ) do={
         if ( $debug = true) do={ :put ("[debug] [replace] keywordRanges:" . [:tostr $keywordRanges;]) }
        # 从开始到关键字位置的字符存入 result
        :set result ($result . [:pick $string $pos ($keywordRanges->"startPos")])
        # 插入目标字符
        :set result ($result . $value)
        # 跳过原关键字
        :set pos ($keywordRanges->"endPos")
        # 继续查找下一个关键字
        :set keywordRanges [
            $findKeywordRanges \
                string=$string \
                keyWord=$keyWord \
                key=$key \
                startKey=$startKey \
                endKey=$endKey \
                startPos=$pos
        ]
    }
    # 将结尾的数据存入 result
    if ( $pos < $maxPos ) do={
        :set result ($result . [:pick $string $pos $maxPos])
    }
    return $result
}

return {
    "moduleName"="replace";
    "replace"=$replace;
}