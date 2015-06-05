package scopes;

import haxe.macro.Expr;
using haxe.macro.ExprTools;

class Syntax {
#if macro

  public static function build() {
    return haxe.macro.Context.getBuildFields().map(transformField);
  }

  static function transformField(field: Field) {
    switch (field.kind) {
      case FFun(fun): 
        transform(fun.expr);
      case FVar(_, e):
        transform(e);
      case FProp(_, _, _, e):
        transform(e);
      default: {}
    }

    return field;

  }

  static function transform(ex: Expr) 
    switch (ex) {
      case macro @protect { protected: $prot, cleanup: $clean }:
        transform(prot); transform(clean);
        ex.expr = (macro scopes.Protect.protect($prot, $clean)).expr;
      case { expr: EMeta({ name: "quell", params: excs }, expr) }: {
        transform(expr);
        //FIXME indentation gone wild.
        ex.expr =
          ECall({ expr:
            EField({ expr:
              EField( { expr: EConst(CIdent("scopes")), pos: expr.pos }, "Protect" ),
            pos: expr.pos }, "quell"),
          pos: expr.pos },
          [ expr ].concat(excs)) ;
      }
      case { expr: EBlock(el) }: {
        ex.iter(transform);
        ex.expr = transformBlock(el).expr;
      }
      default:
        ex.iter(transform);
    }


  static function transformBlock(el: Array<Expr>) {
    var hasExits = false;

    var idx = 0;

    while(idx < el.length) {
      var ex = el[idx];
      switch (ex) {
        case macro @scope $x, macro @SCOPE $x, macro @closes $x, macro @CLOSES $x:
          hasExits = true;
        case macro @scope($v) $x, macro @SCOPE($v) $x,
             macro @closes($v) $x, macro @CLOSES($v) $x:
          hasExits = true;
        default: {}
      }
      idx++;
    }

    if (hasExits) return macro scopes.Scope.withExits($b{el});
    else return macro $b{el};
  }

#end
}
