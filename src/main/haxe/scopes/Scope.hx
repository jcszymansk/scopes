package scopes;

import haxe.macro.Expr;
import haxe.macro.Context;
import scopes.Util.*;

using haxe.macro.ExprTools;


class Scope {

  public static macro function withExits(ex: Expr)
    return switch (ex) {
      case { expr: EBlock(el) }: {
        transform(el, ex.pos);
      }
      default: Context.error("Scope.withExits requires a block", ex.pos);
    }

#if macro
  private static function transform(el: Array<Expr>, mpos: Position) {
    var ret = [];

    var arrName = genSym();

    for (exp in el) switch (exp) {
      case macro @scope $expr:
        ret.push(macro $i{arrName}.unshift({ fail: null, run: function() $expr }));
      case macro @scope($when) $expr:
        ret.push(macro $i{arrName}.unshift({ fail: $when, run: function() $expr }));
      case macro @SCOPE $expr:
        ret.push(macro $i{arrName}.unshift(
              { fail: null, run: function() try $expr catch (_: Dynamic) {} }));
      case macro @SCOPE($when) $expr:
        ret.push(macro $i{arrName}.unshift(
              { fail: $when, run: function() try $expr catch (_: Dynamic) {} }));
      case { expr: EMeta({ name: "closes", params: []}, { expr: EVars(vars), pos: pos }) }: {
        for (vardecl in vars) {
          ret.push({ expr: EVars([ vardecl ]), pos: pos });
          ret.push(macro $i{arrName}.unshift({ fail: null, run: function() $i{vardecl.name}.close() }));
        }
      }
      case { expr: EMeta({ name: "closes", params: [ { expr: EConst(CString(func)) } ]},
                         { expr: EVars(vars), pos: pos }) }: {
        for (vardecl in vars) {
          ret.push({ expr: EVars([ vardecl ]), pos: pos });
          ret.push(macro $i{arrName}.unshift({ fail: null, run: function() $i{vardecl.name}.$func() }));
        }
      }
      case { expr: EMeta({ name: "CLOSES", params: []}, { expr: EVars(vars), pos: pos }) }: {
        for (vardecl in vars) {
          ret.push({ expr: EVars([ vardecl ]), pos: pos });
          ret.push(macro $i{arrName}.unshift(
                { fail: null, run: function() try $i{vardecl.name}.close() catch(_: Dynamic) {} }));
        }
      }
      case { expr: EMeta({ name: "CLOSES", params: [ { expr: EConst(CString(func)) } ]},
                         { expr: EVars(vars), pos: pos }) }: {
        for (vardecl in vars) {
          ret.push({ expr: EVars([ vardecl ]), pos: pos });
          ret.push(macro $i{arrName}.unshift(
                { fail: null, run: function() try $i{vardecl.name}.$func() catch (_: Dynamic) {} }));
        }
      }
      default:
        ret.push(exp);
    }

    var statusName = genSym();
    var counter = genSym();

    var typed: Util.TypedExpression = ({ expr: (macro {
      var $arrName: Array<scopes.Scope.ExitFunc> = [];

      $b{ret};
    }).expr, pos: mpos} :Expr);

    var block;
    switch((typed: Expr).expr) {
      case EBlock([_, { expr: EBlock(unmacroed), pos: bpos }]):
        block = { expr: EBlock(unmacroed), pos: bpos };
      default: throw "internal error";
    }

    
    return checkReturns(macro {
      var $arrName: Array<scopes.Scope.ExitFunc> = [];

      ${scopes.Protect.protectBuild(macro $block, macro {

        for ($i{counter} in $i{arrName}) 
          if (($i{counter}.fail == null) || ($i{counter}.fail == $i{statusName}))
            ($i{counter}.run)();

      }, statusName, typed.getType())}

    }, arrName);




    //return prep;
  }


  private static function checkReturns(ex: Expr, arr: String) {
    return switch(ex) {
      case macro $arr.unshift({ fail: $when, run: ${{ expr: EFunction(_, fun) }} }): checkReturnsSub(fun.expr); ex;
      default: ex.map(checkReturns.bind(_, arr));
    }
    
  }

  private static function checkReturnsSub(ex: Expr) {
    return switch(ex) {
      case { expr: EReturn(_) }: Context.fatalError("return not allowed in scope exits", ex.pos);
      case { expr: EFunction(_, _) }: ex;
      default: ex.map(checkReturnsSub);
    }
  }

#else
  private static function transform(el: Array<Expr>) 
    throw "Only for macros";
#end

}

typedef ExitFunc = {
  var fail: Null<Bool>;
  var run: Void -> Void;
}
