package scopes;

import haxe.macro.Expr;

class SupportMacros {

  
  public static macro function retVal(ex: Expr)
    return macro return $ex;

  public static macro function cont(ex: Expr) 
    return macro continue;

  public static macro function brk(ex: Expr) 
    return macro break;

  public static macro function fun(ex: Expr)
    return macro function() $ex;

  public static macro function times(aCount: ExprOf<Int>, ex: Expr)
    return macro for (__protect_test_cnt_var in 0...$aCount) $ex;
  
}
