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

import haxe.macro.*;
import haxe.macro.Expr;
import scopes.Util.*;

using haxe.macro.ExprTools;

class Protect {

  public static macro function protect(protected: Expr, cleanup: Expr) {

    return protectBuild(expandMacros(protected), cleanup, genSym(), genSym());
  }

  public static macro function quell(quelled: Expr, exceptions: Array<Expr>) {

    if (exceptions.length == 0) return macro try $quelled catch(_:Dynamic) {}
    else {
      var cc = [];
      for (tt in exceptions) {
        switch (tt.expr) {
          case EConst(CIdent(t)): cc.push({ type: Context.toComplexType(Context.getType(t)), name: genSym(), expr: macro {} });
          case EField(e, n): {
            cc.push({ type: Context.toComplexType(Context.getType(recParseDotted(e, n))), name: genSym(), expr: macro{} });
          }
          default: Context.fatalError('use @quell(type1, type2, type2) expr, got: ${tt.expr}', quelled.pos);
        }
      }
      return { expr: ETry(quelled, cc), pos: quelled.pos };
    }

  }

  @:allow(scopes.Scope)
#if macro
  private static function protectBuild(protected: Expr, cleanup: Expr, statusName: String, excName: String) {
    var flags = new TransformFlags();
    var transformed = transform(protected, flags);

//    var excName = genSym();
    var protVName = genSym();

    var useReturn = Context.getExpectedType() == null && needReturn(protected);

    var isVoid = Context.getExpectedType() == null;

    var defvar = macro null;

    try {
      var stype = Context.typeof(protected);

      defvar = switch(stype) {
        case TAbstract(t, _):
          switch(t.get()) {
            case { module: "StdTypes", pack: [], name: "Int" }: macro 0;
            case { module: "StdTypes", pack: [], name: "Float" }: macro 0.0;
            case { module: "StdTypes", pack: [], name: "Bool" }: macro false;
            case { module: "StdTypes", pack: [], name: "Void" }: macro false;
            default: macro null;
          }
        default: macro null;

      }
    }
    catch (_:Dynamic) {}


    var retName = genSym();

    var retExpr = macro {

      var $retName = ${defvar};

      try {
        ${ if(isVoid) macro $transformed else macro $i{retName} = $transformed };
        throw scopes.Protect.ControlException.PassedOK;
      }
      catch ($excName: scopes.Protect.ControlException) {

        var $statusName: Null<Bool> = true;

        $cleanup;

        switch ($i{excName}) {
          case scopes.Protect.ControlException.PassedOK:
            {}
          case scopes.Protect.ControlException.ReturnVoid:
            ${ flags.returnsVoid ? macro { return; } : macro {} };
          case scopes.Protect.ControlException.ReturnValue($i{protVName}):
            ${ flags.returnsValue ? macro { return $i{protVName}; } : macro {} };
          case scopes.Protect.ControlException.Break:
            ${ flags.breaks ? macro { break; } : macro {} };
          case scopes.Protect.ControlException.Continue: 
            ${ flags.continues ? macro { continue; } : macro {} };

        }
      }
      catch ($excName: Dynamic) {
        var $statusName: Null<Bool> = false;

        $cleanup;

        ${ rethrow(excName) };
      }

      ${ if (useReturn) macro throw scopes.Protect.ProtectException.ShouldNotReach else if (!isVoid) macro $i{retName} else macro 1};

    };


    return retExpr;
  }
#else
  private static function protectBuild(protected: Expr, cleanup: Expr, statusName: String)
    throw "Must be called from a macro";
#end

  private static function transform(expr: Expr, flags: TransformFlags, ?inLoop = false): Expr {
    return switch(expr) {
      case macro break if (!inLoop):
        flags.breaks = true;
        macro throw scopes.Protect.ControlException.Break;
      case macro continue if (!inLoop):
        flags.continues = true;
        macro throw scopes.Protect.ControlException.Continue;
      case macro return:
        flags.returnsVoid = true;
        macro throw scopes.Protect.ControlException.ReturnVoid;
      case macro return $val:
        flags.returnsValue = true;
        macro throw scopes.Protect.ControlException.ReturnValue($val);
      case { expr: EFunction(_, _) }:
        expr;
      case { expr: EFor(it, body) }:
        { pos: expr.pos, expr: EFor(it, transform(body, flags, true)) };
      case { expr: EWhile(ecnd, exp, norm) }:
        { pos: expr.pos, expr: EWhile(ecnd, transform(exp, flags, true), norm) };
      case { expr: ETry(tryexp, catches) }: {

        if (catches.length > 0 && 
            ComplexTypeTools.toString(catches[0].type) == "scopes.Protect.ControlException")
          expr;
        else {

          var ncatches = catches.map(function(cExp) {
            return {
              name : cExp.name,
              type : cExp.type, 
              expr: transform(cExp.expr, flags, inLoop) };
          });

          var excName = genSym();

          ncatches.unshift({
            name: excName,
            type: macro :scopes.Protect.ControlException,
            expr: macro throw $i{excName}
          });

          { pos: expr.pos, expr: ETry(transform(tryexp, flags, inLoop), ncatches) };

        }
      }
      default: 
        var trans = transform.bind(_, flags, inLoop);
        expr.map(trans);

    }
  }

#if macro
  private static function recParseDotted(ex: Expr, n: String) {
    return switch(ex.expr) {
      case EConst(CIdent(name)): '${name}.${n}';
      case EField(exx, nn): recParseDotted(exx, '${nn}.${n}');
      default: Context.fatalError('use @quell(type1, type2, type2) expr', ex.pos);

    };
  }


  // check if all branches of ex end with return or throw
  private static function needReturn(ex: Expr): Bool {
    return switch (ex) {

      case null |
           { expr: EBreak } |
           { expr: EConst(_) } |
           { expr: EFunction(_, _) }:
        false;

      case { expr: EContinue } |
           { expr: EThrow(_) }:
        true;           

      case { expr: EReturn(expr) }:
        expr != null;

      case { expr: EBlock(exs) }:
        if (exs.length == 0) false else needReturn(exs[exs.length - 1]);

      case { expr: EBinop(_, e1, e2) } |
           { expr: EIf(_, e1, e2) }:
        needReturn(e1) && needReturn(e2);

      case { expr: ETernary(e1, e2, e3) }:
        Util.all([e1, e2, e3].map(needReturn));

      case { expr: ESwitch(_, cases, def) }:
        Util.all(cases.map(function (c) return needReturn(c.expr))) && needReturn(def);

      case { expr: EVars(decls) }:
        Util.all(decls.map(function(d) return needReturn(d.expr)));

      case { expr: EObjectDecl(decls) }:
        Util.all(decls.map(function(d) return needReturn(d.expr)));

      case { expr: ENew(_, exs) } |
           { expr: ECall(_, exs) } |
           { expr: EArrayDecl(exs) }:
        exs.length > 0 && Util.all(exs.map(needReturn));

      case { expr: EFor(_, expr) } |
           { expr: EWhile(_, expr, _) } |
           { expr: ECast(expr, _) } |
           { expr: ECheckType(expr, _) } |
           { expr: EParenthesis(expr) } |
           { expr: EArray(_, expr) } |
           { expr: EField(expr, _) } |
           { expr: EUnop(_, _, expr) } |
           { expr: EDisplay(expr, _) } |
           { expr: EMeta(_, expr) }:
        needReturn(expr);

      case { expr: ETry(tried, catches) }:
        needReturn(tried) && Util.all(catches.map(catchNeedsReturn));

      default: 
        false; // dunno

    };
  }

  private static function catchNeedsReturn(c: Catch) {
    if (ComplexTypeTools.toString(c.type) == "scopes.Protect.ControlException")
      return true;
    else
      return needReturn(c.expr);
  }
#end


}

private class TransformFlags {
  public var returnsValue(default, default): Bool = false;
  public var returnsVoid(default, default): Bool = false;
  public var breaks(default, default): Bool = false;
  public var continues(default, default): Bool = false;

  public function new() {}
}

enum ControlException {
  PassedOK;
  ReturnVoid;
  ReturnValue(value: Dynamic);
  Break;
  Continue;
}

enum ProtectException {
  ShouldNotReach;
}
