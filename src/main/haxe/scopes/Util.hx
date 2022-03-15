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
      macro @:pos(Context.currentPos()) $i{platform}.Lib.rethrow($i{e});
    else 
      macro @:pos(Context.currentPos()) throw $i{e};
  }

  public static function typeExprSafer(expr: Expr): TypedExpr {
    if (expr == null) return null;

    var typed = Context.typeExpr(macro { $expr; 1; });

    return switch(typed) {
      case { expr: TBlock([ tp, _ ])}: tp;
      default: throw "should never happen, did it?";
    };
  }
#end

  public static function all(vals: Array<Bool>): Bool {
    for (val in vals) if (val != true) return false;
    return true;
  }

  public inline static function thisIsVoid(): Void {}

}

