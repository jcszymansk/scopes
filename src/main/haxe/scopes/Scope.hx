package scopes;

import haxe.macro.Expr;
import haxe.macro.Context;
import scopes.Util.*;

using haxe.macro.ExprTools;


class Scope {

  public static macro function withExits(ex: Expr) {

    return doWithExits(ex);
  }

#if macro
  private static function doWithExits(ex: Expr) {
    return switch (ex) {
      case { expr: EBlock(el) }: {
        transform(el, ex.pos);
      }
      case macro scopes.Scope.withExits($el): doWithExits(el);
      default: Context.error("Scope.withExits requires a block", ex.pos);
    }
    
  }

  private static function transform(el: Array<Expr>, mpos: Position) {
    var ret = [];

    var arrName = genSym();
    var ignName = genSym();

    for (exp in el) switch (exp) {
      case macro @scope $expr:
        ret.push(macro $i{arrName}.unshift({ fail: null, run: function($ignName) $expr }));
      //case macro @scope(@as(${{ expr: EConst(CIdent(name)) }}) ${{ expr: EConst(CIdent(when)) }}) $expr:
      case { expr: EMeta({ name: "scope", params: [ {
        expr: EMeta({ name: "as", params: [ { expr: EConst(CIdent(name)) } ] }, when)
      } ] }, expr ) }:
        ret.push(macro $i{arrName}.unshift({ fail: $when,
                     run: ${{expr: EFunction(null, { ret: (macro :Void), expr: expr, args: [{ name: name, type: null }] } ),
                             pos: mpos }}})); 
      case macro @scope($when) $expr:
        ret.push(macro $i{arrName}.unshift({ fail: $when, run: function($ignName) $expr }));
      case macro @SCOPE $expr:
        ret.push(macro $i{arrName}.unshift(
              { fail: null, run: function($ignName) try $expr catch (_: Dynamic) {} }));
      case { expr: EMeta({ name: "SCOPE", params: [ {
        expr: EMeta({ name: "as", params: [ { expr: EConst(CIdent(name)) } ] }, when)
      } ] }, expr ) }:
        ret.push(macro $i{arrName}.unshift({ fail: $when,
                     run: ${{expr: EFunction(null, { ret: (macro :Void),
                                               expr: (macro try $expr catch(_:Dynamic) {}),
                                               args: [{ name: name, type: null }] } ),
                             pos: mpos }}})); 
      case macro @SCOPE($when) $expr:
        ret.push(macro $i{arrName}.unshift(
              { fail: $when, run: function($ignName) try $expr catch (_: Dynamic) {} }));
      case { expr: EMeta({ name: "closes", params: []}, { expr: EVars(vars), pos: pos }) }: {
        for (vardecl in vars) {
          ret.push({ expr: EVars([ vardecl ]), pos: pos });
          ret.push(macro $i{arrName}.unshift({ fail: null, run: function($ignName) $i{vardecl.name}.close() }));
        }
      }
      case { expr: EMeta({ name: "closes", params: [ { expr: EConst(CString(func)) } ]},
                         { expr: EVars(vars), pos: pos }) }: {
        for (vardecl in vars) {
          ret.push({ expr: EVars([ vardecl ]), pos: pos });
          ret.push(macro $i{arrName}.unshift({ fail: null, run: function($ignName) $i{vardecl.name}.$func() }));
        }
      }
      case { expr: EMeta({ name: "CLOSES", params: []}, { expr: EVars(vars), pos: pos }) }: {
        for (vardecl in vars) {
          ret.push({ expr: EVars([ vardecl ]), pos: pos });
          ret.push(macro $i{arrName}.unshift(
                { fail: null, run: function($ignName) try $i{vardecl.name}.close() catch(_: Dynamic) {} }));
        }
      }
      case { expr: EMeta({ name: "CLOSES", params: [ { expr: EConst(CString(func)) } ]},
                         { expr: EVars(vars), pos: pos }) }: {
        for (vardecl in vars) {
          ret.push({ expr: EVars([ vardecl ]), pos: pos });
          ret.push(macro $i{arrName}.unshift(
                { fail: null, run: function($ignName) try $i{vardecl.name}.$func() catch (_: Dynamic) {} }));
        }
      }
      default:
        ret.push(exp);
    }

    var statusName = genSym();
    var counter = genSym();
    var excName = genSym();

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

        for ($i{counter} in $i{arrName}) {
          if (($i{counter}.fail == null) ||
                 ($i{counter}.fail == $i{statusName}))
            ($i{counter}.run)(null);
          else if (!Std.is($i{counter}.fail, Bool) && Std.is($i{excName}, $i{counter}.fail)) {
            ($i{counter}.run)($i{excName});
          }
        }


      }, statusName, typed.getType(), excName)}

    }, arrName);




    //return prep;
  }

  private static function recParseDotted(ex: Expr, n: String) {
    return switch(ex.expr) {
      case EConst(CIdent(name)): '${name}.${n}';
      case EField(exx, nn): recParseDotted(exx, '${nn}.${n}');
      default: Context.fatalError('use @quell(type1, type2, type2) expr', ex.pos);
 
    };
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
  var fail: Null<Dynamic>;
  var run: Dynamic;
}
