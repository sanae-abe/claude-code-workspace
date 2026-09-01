# Velocity Template Patterns

Common Apache Velocity syntax patterns for `.vm` files.

## Macro Definition

```velocity
#macro(macroName $param)
  #set($var = "value")
  ## comment
#end
```

## Variable Manipulation

```velocity
#set($var = $object.property)
#set($var = $stringUtils.replace($var, '[placeholder]', "$value"))
```

## Conditional

```velocity
#if($condition && $condition != "")
  ## content
#elseif($other)
  ## content
#else
  ## content
#end
```

## Loop

```velocity
#foreach($item in $list)
  $item.property
#end
```

## Include / Parse

```velocity
#include("file.vm")
#parse("file.vm")
```

## Escaped Output

```velocity
$!{variable}       ## suppress null output
${variable}        ## standard output
\$variable         ## literal dollar sign
```
