/****
* Copyright (c) 2015-2022 Jacek Szymanski
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
import haxe.macro.Type;

import scopes.Util.*;

using haxe.macro.ExprTools;
using haxe.macro.TypedExprTools;
using haxe.macro.TypeTools;

class Protect {

  public static macro function protect(protected: Expr, cleanup: Expr) {
    return protectBuild(macro {}, protected, macro $b{[cleanup]});
  }

  public static macro function quell(quelled: Expr, exceptions: Array<Expr>) {

    if (exceptions.length == 0) return macro try $quelled catch(_:Dynamic) {}
    else {
      var cc = [];
      for (tt in exceptions) {
        switch (tt.expr) {
          case EConst(CIdent(t)): cc.push({ type: Context.toComplexType(Context.getType(t)), name: genSym(), expr: macro { scopes.Util.thisIsVoid(); } });
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
  private static function protectBuild(bindings: Expr, protected: Expr, cleanup: Expr): Expr {
    var flags = new TransformFlags();

    var excName = genSym();
    var protVName = genSym();

    var pretyped = switch(Context.typeExpr(macro {
      $bindings;

      $protected;
    })) {
      case { expr:TBlock(block) }: block[block.length - 1];
      case any: throw 'should never happen ' + TypedExprTools.toString(any);
    }

    transform(pretyped, flags); // must pre-transform as well for flags

    var useReturn = Context.getExpectedType() == null && needReturn(pretyped);

    var isVoid = Context.getExpectedType() == null;

    var defvar = macro null;

    try {
      var stype = pretyped.t;

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

      };
    }
    catch (_:Dynamic) {}

    var realCleanup = switch(cleanup) {
      case { expr: EFunction(_, _) }: macro ${cleanup}($i{excName});
      default: cleanup;
    }

    var retName = genSym();

    var retExpr = macro {

      $e{bindings};

      var $retName = ${defvar};

      try {
        ${ if(isVoid) macro $protected else macro $i{retName} = $protected };
        throw scopes.Protect.ControlException.PassedOK;
      }
      catch ($excName: scopes.Protect.ControlException) {
        $e{realCleanup};

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
        $e{realCleanup};

        ${ rethrow(excName) };
      }

      ${ if (useReturn) macro throw scopes.Protect.ProtectException.ShouldNotReach else if (!isVoid) macro $i{retName} else macro 1};

    };

    var typedRet = Context.typeExpr(retExpr);

    var protExpTryBlock = switch(typedRet.expr) { // paranoid sanity checks ahead
      case TBlock(tblock): switch (tblock[tblock.length - 2].expr) {
        case TTry({ expr : TBlock(triesBlock) }, _): switch (triesBlock) {
          case [_, _]: triesBlock;
          default: throw "should not happend";
        };
        default: throw "should not happend";
      }
      default: throw "should not happend";
    };

    switch (protExpTryBlock[0]) {
      case { expr: TBinop(OpAssign, rt, prot) }: protExpTryBlock[0].expr = TBinop(OpAssign, rt, transform(prot, flags));
      case prot: protExpTryBlock[0].expr = transform(prot, flags).expr;
    }

    return Context.storeTypedExpr(typedRet);
  }
#else
  private static function protectBuild(protected: Expr, cleanup: Expr, statusName: String)
    throw "Must be called from a macro";
#end

#if macro
  private static function transform(expr: TypedExpr, flags: TransformFlags, ?inLoop = false): TypedExpr {
    return switch(expr) {
      case { expr: TBreak } if (!inLoop):
        flags.breaks = true;
        Context.typeExpr(macro @:pos(expr.pos) throw scopes.Protect.ControlException.Break);
      case { expr: TContinue } if (!inLoop):
        flags.continues = true;
        Context.typeExpr(macro @:pos(expr.pos) throw scopes.Protect.ControlException.Continue);
      case { expr: TReturn(null) }:
        flags.returnsVoid = true;
        Context.typeExpr(macro @:pos(expr.pos) throw scopes.Protect.ControlException.ReturnVoid);
      case { expr: TReturn(val) }:
        var tval = Context.storeTypedExpr(val);
        flags.returnsValue = true;
        Context.typeExpr(macro @:pos(expr.pos) throw scopes.Protect.ControlException.ReturnValue($tval));
      case { expr: TFunction(_) }:
        expr;
      case { expr: TFor(vr, it, body) }:
        { pos: expr.pos,
          t: expr.t,
          expr: TFor(vr,
                    it,
                    transform(body, flags, true)) };
      case { expr: TWhile(ecnd, exp, norm) }:
        { pos: expr.pos,
          t: expr.t,
          expr: TWhile(ecnd,
              transform(exp, flags, true), norm) };
      case { expr: TTry(tryexp, catches) }: {
        if (catches.length > 0 && isControlException(catches[0].v.t))
            //ComplexTypeTools.toString(catches[0].type) == "scopes.Protect.ControlException")
          expr;
        else {

          var trytr = transform(tryexp, flags, inLoop);

          var ncatches = catches.map(function(cExp) {
            return {
              v: cExp.v,
              expr: transform(cExp.expr, flags, inLoop) };
          });

          var excName = genSym();

          var typedtry = Context.typeExpr(
            macro try { throw false; } catch ($excName: scopes.Protect.ControlException) { throw $i{excName}; }
            );

          var ncatch = switch(typedtry) {
            case { expr: TTry(_, [ nc ])}: nc;
            default: throw "impossible?" + typedtry;
          };



          ncatches.unshift(ncatch);

          { pos: expr.pos, t: expr.t, expr: TTry(trytr, ncatches) };

        }
      }
      default:
        var trans = transform.bind(_, flags, inLoop);
        expr.map(trans);

    }
  }

  private static function recParseDotted(ex: Expr, n: String) {
    return switch(ex.expr) {
      case EConst(CIdent(name)): '${name}.${n}';
      case EField(exx, nn): recParseDotted(exx, '${nn}.${n}');
      default: Context.fatalError('use @quell(type1, type2, type2) expr', ex.pos);

    };
  }

  private static function isControlException(t: Type) {
    return switch(t) {
      case TEnum(_.toString() => "scopes.ControlException", _): true;
      default: false;
    };
  }


  // check if all branches of ex end with return or throw
  private static function needReturn(ex: TypedExpr): Bool {
    return switch (ex) {

      case null |
           { expr: TBreak } |
           { expr: TConst(_) } |
           { expr: TFunction(_) }:
        false;

      case { expr: TContinue } |
           { expr: TThrow(_) }:
        true;

      case { expr: TReturn(expr) }:
        expr != null;

      case { expr: TBlock(exs) }:
        if (exs.length == 0) false else needReturn(exs[exs.length - 1]);

      case { expr: TBinop(_, e1, e2) } |
           { expr: TFor(_, e1, e2) } |
           { expr: TArray(e1, e2) } |
           { expr: TWhile(e1, e2, _) }:
        needReturn(e1) && needReturn(e2);

      case { expr: TCall(e1, e2) }:
        needReturn(e1) || ( e2.length > 0 && Util.all(e2.map(needReturn)));

      case { expr: TIf(e1, e2, e3) }:
        Util.all([e1, e2, e3].map(needReturn));

      case { expr: TSwitch(e1, cases, def) }:
        needReturn(e1) && Util.all(cases.map(function (c) return needReturn(c.expr))) && needReturn(def);

      case { expr: TVar(_, ex) }:
        needReturn(ex);

      case { expr: TObjectDecl(decls) }:
        Util.all(decls.map(function(d) return needReturn(d.expr)));

      case { expr: TNew(_, _, exs) } |
           { expr: TArrayDecl(exs) }:
        exs.length > 0 && Util.all(exs.map(needReturn));

      case { expr: TCast(expr, _) } |
           { expr: TParenthesis(expr) } |
           { expr: TField(expr, _) } |
           { expr: TUnop(_, _, expr) } |
           { expr: TMeta(_, expr) }:
        needReturn(expr);

      case { expr: TTry(tried, catches) }:
        needReturn(tried) && Util.all(catches.map(catchNeedsReturn));

      default:
        false; // dunno

    };
  }

  private static function catchNeedsReturn(c: {v: TVar, expr: TypedExpr}) {
    if (isControlException(c.v.t))
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
