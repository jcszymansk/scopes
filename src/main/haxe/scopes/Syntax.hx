/****
* Copyright (c) 2015 Parensoft.NET
* 
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
* 
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
* 
****/

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
    if (ex != null) switch (ex) {
      case macro @protect { protected: $prot, cleanup: $clean }:
        transform(prot); transform(clean);
        ex.expr = (macro scopes.Protect.protect($prot, $clean)).expr;
      case { expr: EMeta({ name: "quell", params: excs }, expr) }: {
        expr.iter(transform);
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
