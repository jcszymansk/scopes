package scopes;

import buddy.*;
using buddy.Should;

class ScopeTest extends BuddySuite {

  public function new() {

    describe("scope exit basic tests", {
      /* FIXME ALL TESTS FAIL ON H4
      it("should execute on exit", {
        var control = [];

        Scope.withExits({
          @scope control.push("two");
          control.push("one");
        });

        control.should.containExactly(["one", "two"]);
      });

      it("should observe true/false/null", {
        var control = [];

        Scope.withExits({
          @scope(true) control.push("true");
          @scope(null) control.push("null");
          @scope(false) control.push("false");
          control.push("start");
        });

        control.should.containExactly(["start", "null", "true"]);
      });

      it("should observe true/false/null on exception", {
        var control = [];

        try Scope.withExits({
          @scope(true) control.push("true");
          @scope(null) control.push("null");
          @scope(false) control.push("false");
          control.push("start");
          throw "out";
        })
        catch (e: String) control.push(e);

        control.should.containExactly(["start", "false", "null", "out"]);
      });

      it("should observe autoclose variables", {

        var control = [];

        Scope.withExits({
          @closes var closed = {
            close: function() control.push("close")
          };

          control.push("start");
        });

        control.should.containExactly(["start", "close"]);
      });

      it("should observe autoclose variables 2", {

        var control = [];

        Scope.withExits({
          @closes var closed = {
            close: function() control.push("close"),
            check: function() control.push("check")
          };

          control.push("start");

          closed.check();
        });

        control.should.containExactly(["start", "check", "close"]);
      });

      it("should observe autoclose variables with named close func", {

        var control = [];

        Scope.withExits({
          @closes("dispose") var closed = {
            dispose: function() control.push("close")
          };

          control.push("start");
        });

        control.should.containExactly(["start", "close"]);
      });
*/

      /*
      it("should disallow return in @scope", {
        Scope.withExits({
          @scope return;
          1;
        });
        
        1.should.be(2);
      });
      */

    });

  }

}

