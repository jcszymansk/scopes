package scopes;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class Util {

  private static var genSymCounter: Int = 1000;

  public static function genSym(?base: String = "__net_parensoft_protect") {
    genSymCounter++;

    return '${base}_${genSymCounter}';
  }
  
#if macro
  private static var platform: String =
    if (Context.defined("neko")) "neko";
    else if (Context.defined("cpp")) "cpp";
    else if (Context.defined("php")) "php";
    else null;

    public static function rethrow(e: String) 
      return if (platform != null) 
        macro $i{platform}.Lib.rethrow($i{e});
      else 
        macro throw $i{e};
#end

}

#if macro
abstract TypedExpression(TypedExpr) from TypedExpr to TypedExpr {
  
  public function new(aThis: TypedExpr) this = aThis;

  @:from public static function fromExpr(anExpr: Expr)
    return new TypedExpression(Context.typeExpr(anExpr));

  @:to public function toExpr()
    return Context.getTypedExpr(this);

  public function getType()
    return this.t;
}
#end
