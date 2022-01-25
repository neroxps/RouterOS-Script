# 本脚本修改自 https://github.com/Winand/mikrotik-json-parser/raw/master/JParseFunctions
# -------------------------------- JsonParse ---------------------------------------------------
# ------------------------------- "JsonParse::print" ----------------------------------------------------------------
:global "JsonParse::print"
:if (!any $"JsonParse::print") do={ :global "JsonParse::print" do={
  :global "JsonParse::parseOut"
  :local TempPath
  :global "JsonParse::print"

  :if ([:len $1] = 0) do={
    :set $1 "\$JsonParse::parseOut"
    :set $2 $"JsonParse::parseOut"
   }
   
  :foreach k,v in=$2 do={
    :if ([:typeof $k] = "str") do={
      :set k "\"$k\""
    }
    :set TempPath ($1. "->" . $k)
    :if ([:typeof $v] = "array") do={
      :if ([:len $v] > 0) do={
        $"JsonParse::print" $TempPath $v
      } else={
        :put "$TempPath = [] ($[:typeof $v])"
      }
    } else={
        :put "$TempPath = $v ($[:typeof $v])"
    }
  }
}}
# ------------------------------- "JsonParse::printVar" ----------------------------------------------------------------
:global "JsonParse::printVar"
:if (!any $"JsonParse::printVar") do={ :global "JsonParse::printVar" do={
  :global "JsonParse::parseOut"
  :local TempPath
  :global "JsonParse::printVar"
  :local fJParsePrintRet ""

  :if ([:len $1] = 0) do={
    :set $1 "\$JsonParse::parseOut"
    :set $2 $"JsonParse::parseOut"
   }
   
  :foreach k,v in=$2 do={
    :if ([:typeof $k] = "str") do={
      :set k "\"$k\""
    }
    :set TempPath ($1. "->" . $k)
    :if ($fJParsePrintRet != "") do={
      :set fJParsePrintRet ($fJParsePrintRet . "\r\n")
    }    
    :if ([:typeof $v] = "array") do={
      :if ([:len $v] > 0) do={
        :set fJParsePrintRet ($fJParsePrintRet . [$"JsonParse::printVar" $TempPath $v])
      } else={
        :set fJParsePrintRet ($fJParsePrintRet . "$TempPath = [] ($[:typeof $v])")
      }
    } else={
        :set fJParsePrintRet ($fJParsePrintRet . "$TempPath = $v ($[:typeof $v])")
    }
  }
  :return $fJParsePrintRet
}}
# ------------------------------- "JsonParse::skipWhitespace" ----------------------------------------------------------------
:global "JsonParse::skipWhitespace"
:if (!any $"JsonParse::skipWhitespace") do={ :global "JsonParse::skipWhitespace" do={
  :global "JsonParse::jsonPos"
  :global "JsonParse::jsonIn"
  :global "JsonParse::debug"
  :while ($"JsonParse::jsonPos" < [:len $"JsonParse::jsonIn"] and ([:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"] ~ "[ \r\n\t]")) do={
    :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
  }
  :if ($"JsonParse::debug") do={:put ("JsonParse::skipWhitespace: JsonParse::jsonPos=$JsonParse::jsonPos Char=$[:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]")}
}}
# -------------------------------- "JsonParse::parse" ---------------------------------------------------------------
:global "JsonParse::parse"
:if (!any $"JsonParse::parse") do={ :global "JsonParse::parse" do={
  :global "JsonParse::jsonPos"
  :global "JsonParse::jsonIn"
  :global "JsonParse::debug"
  :global "JsonParse::skipWhitespace"
  :local Char

  :if (!$1) do={
    :set "JsonParse::jsonPos" 0
   }
  
  $"JsonParse::skipWhitespace"
  :set Char [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]
  :if ($"JsonParse::debug") do={:put ("JsonParse::parse: JsonParse::jsonPos=$"JsonParse::jsonPos" Char=$Char")}
  :if ($Char="{") do={
    :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
    :global "JsonParse::parseObject"
    :return [$"JsonParse::parseObject"]
  } else={
    :if ($Char="[") do={
      :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
      :global "JsonParse::parseArray"
      :return [$"JsonParse::parseArray"]
    } else={
      :if ($Char="\"") do={
        :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
        :global "JsonParse::parseString"
        :return [$"JsonParse::parseString"]
      } else={
#        :if ([:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos" ($"JsonParse::jsonPos"+2)]~"^-\?[0-9]") do={
        :if ($Char~"[eE0-9.+-]") do={
          :global "JsonParse::parseNumber"
          :return [$"JsonParse::parseNumber"]
        } else={

          :if ($Char="n" and [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos" ($"JsonParse::jsonPos"+4)]="null") do={
            :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 4)
            :return []
          } else={
            :if ($Char="t" and [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos" ($"JsonParse::jsonPos"+4)]="true") do={
              :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 4)
              :return true
            } else={
              :if ($Char="f" and [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos" ($"JsonParse::jsonPos"+5)]="false") do={
                :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 5)
                :return false
              } else={
                :put "Err.Raise 8732. No JSON object could be fJParseed"
                :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
                :return []
              }
            }
          }
        }
      }
    }
  }
}}

#-------------------------------- "JsonParse::parseString" ---------------------------------------------------------------
:global "JsonParse::parseString"
:if (!any $"JsonParse::parseString") do={ :global "JsonParse::parseString" do={
  :global "JsonParse::jsonPos"
  :global "JsonParse::jsonIn"
  :global "JsonParse::debug"
  :global "JsonParse::unicodeToUTF8"
  :local Char
  :local StartIdx
  :local Char2
  :local TempString ""
  :local UTFCode
  :local Unicode

  :set StartIdx $"JsonParse::jsonPos"
  :set Char [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]
  :if ($"JsonParse::debug") do={:put ("JsonParse::parseString: JsonParse::jsonPos=$"JsonParse::jsonPos" Char=$Char")}
  :while ($"JsonParse::jsonPos" < [:len $"JsonParse::jsonIn"] and $Char != "\"") do={
    :if ($Char="\\") do={
      :set Char2 [:pick $"JsonParse::jsonIn" ($"JsonParse::jsonPos" + 1)]
      :if ($Char2 = "u") do={
        :set UTFCode [:tonum "0x$[:pick $"JsonParse::jsonIn" ($"JsonParse::jsonPos"+2) ($"JsonParse::jsonPos"+6)]"]
        :if ($UTFCode>=0xD800 and $UTFCode<=0xDFFF) do={
# Surrogate pair
          :set Unicode  (($UTFCode & 0x3FF) << 10)
          :set UTFCode [:tonum "0x$[:pick $"JsonParse::jsonIn" ($"JsonParse::jsonPos"+8) ($"JsonParse::jsonPos"+12)]"]
          :set Unicode ($Unicode | ($UTFCode & 0x3FF) | 0x10000)
          :set TempString ($TempString . [:pick $"JsonParse::jsonIn" $StartIdx $"JsonParse::jsonPos"] . [$"JsonParse::unicodeToUTF8" $Unicode])         
          :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 12)
        } else= {
# Basic Multilingual Plane (BMP)
          :set Unicode $UTFCode
          :set TempString ($TempString . [:pick $"JsonParse::jsonIn" $StartIdx $"JsonParse::jsonPos"] . [$"JsonParse::unicodeToUTF8" $Unicode])
          :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 6)
        }
        :set StartIdx $"JsonParse::jsonPos"
        :if ($"JsonParse::debug") do={:put "JsonParse::parseString Unicode: $Unicode"}
      } else={
        :if ($Char2 ~ "[\\bfnrt\"]") do={
          :if ($"JsonParse::debug") do={:put "JsonParse::parseString escape: Char+Char2 $Char$Char2"}
          :set TempString ($TempString . [:pick $"JsonParse::jsonIn" $StartIdx $"JsonParse::jsonPos"] . [[:parse "(\"\\$Char2\")"]])
          :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 2)
          :set StartIdx $"JsonParse::jsonPos"
        } else={
          :if ($Char2 = "/") do={
            :if ($"JsonParse::debug") do={:put "JsonParse::parseString /: Char+Char2 $Char$Char2"}
            :set TempString ($TempString . [:pick $"JsonParse::jsonIn" $StartIdx $"JsonParse::jsonPos"] . "/")
            :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 2)
            :set StartIdx $"JsonParse::jsonPos"
          } else={
            :put "Err.Raise 8732. Invalid escape"
            :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 2)
          }
        }
      }
    } else={
      :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
    }
    :set Char [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]
  }
  :set TempString ($TempString . [:pick $"JsonParse::jsonIn" $StartIdx $"JsonParse::jsonPos"])
  :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
  :if ($"JsonParse::debug") do={:put "JsonParse::parseString: $TempString"}
  :return $TempString
}}

#-------------------------------- "JsonParse::parseNumber" ---------------------------------------------------------------
:global "JsonParse::parseNumber"
:if (!any $"JsonParse::parseNumber") do={ :global "JsonParse::parseNumber" do={
  :global "JsonParse::jsonPos"
  :local StartIdx
  :global "JsonParse::jsonIn"
  :global "JsonParse::debug"
  :local NumberString
  :local Number

  :set StartIdx $"JsonParse::jsonPos"   
  :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
  :while ($"JsonParse::jsonPos" < [:len $"JsonParse::jsonIn"] and [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]~"[eE0-9.+-]") do={
    :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
  }
  :set NumberString [:pick $"JsonParse::jsonIn" $StartIdx $"JsonParse::jsonPos"]
  :set Number [:tonum $NumberString] 
  :if ([:typeof $Number] = "num") do={
    :if ($"JsonParse::debug") do={:put ("JsonParse::parseNumber: StartIdx=$StartIdx JsonParse::jsonPos=$"JsonParse::jsonPos" $Number ($[:typeof $Number])")}
    :return $Number
  } else={
    :if ($"JsonParse::debug") do={:put ("JsonParse::parseNumber: StartIdx=$StartIdx JsonParse::jsonPos=$"JsonParse::jsonPos" $NumberString ($[:typeof $NumberString])")}
    :return $NumberString
  }
}}

#-------------------------------- "JsonParse::parseArray" ---------------------------------------------------------------
:global "JsonParse::parseArray"
:if (!any $"JsonParse::parseArray") do={ :global "JsonParse::parseArray" do={
  :global "JsonParse::jsonPos"
  :global "JsonParse::jsonIn"
  :global "JsonParse::debug"
  :global "JsonParse::parse"
  :global "JsonParse::skipWhitespace"
  :local Value
  :local ParseArrayRet [:toarray ""]
  
  $"JsonParse::skipWhitespace"    
  :while ($"JsonParse::jsonPos" < [:len $"JsonParse::jsonIn"] and [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]!= "]") do={
    :set Value [$"JsonParse::parse" true]
    :set ($ParseArrayRet->([:len $ParseArrayRet])) $Value
    :if ($"JsonParse::debug") do={:put "JsonParse::parseArray: Value="; :put $Value}
    $"JsonParse::skipWhitespace"
    :if ([:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"] = ",") do={
      :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
      $"JsonParse::skipWhitespace"
    }
  }
  :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
#  :if ($"JsonParse::debug") do={:put "ParseArrayRet: "; :put $ParseArrayRet}
  :return $ParseArrayRet
}}

# -------------------------------- "JsonParse::parseObject" ---------------------------------------------------------------
:global "JsonParse::parseObject"
:if (!any $"JsonParse::parseObject") do={ :global "JsonParse::parseObject" do={
  :global "JsonParse::jsonPos"
  :global "JsonParse::jsonIn"
  :global "JsonParse::debug"
  :global "JsonParse::skipWhitespace"
  :global "JsonParse::parseString"
  :global "JsonParse::parse"
# Syntax :local ParseObjectRet ({}) don't work in recursive call, use [:toarray ""] for empty array!!!
  :local ParseObjectRet [:toarray ""]
  :local Key
  :local Value
  :local ExitDo false
  
  $"JsonParse::skipWhitespace"
  :while ($"JsonParse::jsonPos" < [:len $"JsonParse::jsonIn"] and [:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]!="}" and !$ExitDo) do={
    :if ([:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]!="\"") do={
      :put "Err.Raise 8732. Expecting property name"
      :set ExitDo true
    } else={
      :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
      :set Key [$"JsonParse::parseString"]
      $"JsonParse::skipWhitespace"
      :if ([:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"] != ":") do={
        :put "Err.Raise 8732. Expecting : delimiter"
        :set ExitDo true
      } else={
        :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
        :set Value [$"JsonParse::parse" true]
        :set ($ParseObjectRet->$Key) $Value
        :if ($"JsonParse::debug") do={:put "JsonParse::parseObject: Key=$Key Value="; :put $Value}
        $"JsonParse::skipWhitespace"
        :if ([:pick $"JsonParse::jsonIn" $"JsonParse::jsonPos"]=",") do={
          :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
          $"JsonParse::skipWhitespace"
        }
      }
    }
  }
  :set "JsonParse::jsonPos" ($"JsonParse::jsonPos" + 1)
#  :if ($"JsonParse::debug") do={:put "ParseObjectRet: "; :put $ParseObjectRet}
  :return $ParseObjectRet
}}

# ------------------- "JsonParse::byteToEscapeChar" ----------------------
:global "JsonParse::byteToEscapeChar"
:if (!any $"JsonParse::byteToEscapeChar") do={ :global "JsonParse::byteToEscapeChar" do={
#  :set $1 [:tonum $1]
  :return [[:parse "(\"\\$[:pick "0123456789ABCDEF" (($1 >> 4) & 0xF)]$[:pick "0123456789ABCDEF" ($1 & 0xF)]\")"]]
}}

# ------------------- "JsonParse::unicodeToUTF8"----------------------
:global "JsonParse::unicodeToUTF8"
:if (!any $"JsonParse::unicodeToUTF8") do={ :global "JsonParse::unicodeToUTF8" do={
  :global "JsonParse::byteToEscapeChar"
#  :local Ubytes [:tonum $1]
  :local Nbyte
  :local EscapeStr ""

  :if ($1 < 0x80) do={
    :set EscapeStr [$"JsonParse::byteToEscapeChar" $1]
  } else={
    :if ($1 < 0x800) do={
      :set Nbyte 2
    } else={  
      :if ($1 < 0x10000) do={
        :set Nbyte 3
      } else={
        :if ($1 < 0x20000) do={
          :set Nbyte 4
        } else={
          :if ($1 < 0x4000000) do={
            :set Nbyte 5
          } else={
            :if ($1 < 0x80000000) do={
              :set Nbyte 6
            }
          }
        }
      }
    }
    :for i from=2 to=$Nbyte do={
      :set EscapeStr ([$"JsonParse::byteToEscapeChar" ($1 & 0x3F | 0x80)] . $EscapeStr)
      :set $1 ($1 >> 6)
    }
    :set EscapeStr ([$"JsonParse::byteToEscapeChar" (((0xFF00 >> $Nbyte) & 0xFF) | $1)] . $EscapeStr)
  }
  :return $EscapeStr
}}

# ------------------- Load JSON from arg --------------------------------
global "JsonParse::jsonLoads"
if (!any $"JsonParse::jsonLoads") do={ global "JsonParse::jsonLoads" do={
    global "JsonParse::jsonIn" $1
    global "JsonParse::parse"
    local ret [$"JsonParse::parse"]
    set "JsonParse::jsonIn"
    global "JsonParse::jsonPos"; set "JsonParse::jsonPos"
    global "JsonParse::debug"; if (!$"JsonParse::debug") do={set "JsonParse::debug"}
    return $ret
}}

# ------------------- Load JSON from file --------------------------------
global "JsonParse::jsonLoad"
if (!any $"JsonParse::jsonLoad") do={ global "JsonParse::jsonLoad" do={
    if ([len [/file find name=$1]] > 0) do={
        global "JsonParse::jsonLoads"
        return [$"JsonParse::jsonLoads" [/file get $1 contents]]
    }
}}

# ------------------- Unload JSON parser library ----------------------
global "JsonParse::jsonUnLoad"
if (!any $"JsonParse::jsonUnLoad") do={ global "JsonParse::jsonUnLoad" do={
    global "JsonParse::jsonIn"; set "JsonParse::jsonIn"
    global "JsonParse::jsonPos"; set "JsonParse::jsonPos"
    global "JsonParse::debug"; set "JsonParse::debug"
    global "JsonParse::byteToEscapeChar"; set "JsonParse::byteToEscapeChar"
    global "JsonParse::parse"; set "JsonParse::parse"
    global "JsonParse::parseArray"; set "JsonParse::parseArray"
    global "JsonParse::parseNumber"; set "JsonParse::parseNumber"
    global "JsonParse::parseObject"; set "JsonParse::parseObject"
    global "JsonParse::print"; set "JsonParse::print"
    global "JsonParse::printVar"; set "JsonParse::printVar"
    global "JsonParse::parseString"; set "JsonParse::parseString"
    global "JsonParse::skipWhitespace"; set "JsonParse::skipWhitespace"
    global "JsonParse::unicodeToUTF8"; set "JsonParse::unicodeToUTF8"
    global "JsonParse::jsonLoads"; set "JsonParse::jsonLoads"
    global "JsonParse::jsonLoad"; set "JsonParse::jsonLoad"
    global "JsonParse::jsonUnLoad"; set "JsonParse::jsonUnLoad"
    global "JsonParse::parseOut"; set "JsonParse::parseOut"
}}
# ------------------- End JsonParse----------------------