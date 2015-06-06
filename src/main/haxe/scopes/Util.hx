package scopes;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class Util {

  private static var genSymCounter: Int = 1000;

  public static var GENSYM_BASE(default, never) = "__scopes_gensym";

  public static function genSym() {
    genSymCounter++;

    return '${GENSYM_BASE}_${genSymCounter}';
  }
  
#if macro
  private static var platform: String =
    if (Context.defined("neko")) "neko";
    else if (Context.defined("cpp")) "cpp";
    else if (Context.defined("php")) "php";
    else null;

  public static function rethrow(e: String) {
    return if (platform != null) 
      macro $i{platform}.Lib.rethrow($i{e});
    else 
      macro throw $i{e};
  }

  public static function expandMacros(expr: Expr): Expr {
    if (expr == null) return null;

    var expanded = Context.getTypedExpr(Context.typeExpr(macro { $expr; 1; }));

    return switch (expanded) {
      case { expr: EBlock([ { expr: extracted }, _ ])}:
        { expr: extracted, pos: expr.pos };
      default: throw "should never happen. did it?";
    }
  }
#end

  public static function all(vals: Array<Bool>): Bool {
    for (val in vals) if (val != true) return false;
    return true;
  }

}

