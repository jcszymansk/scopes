package scopes;

import buddy.*;
using buddy.Should;

class SyntaxTest extends BuddySuite implements ScopeSyntax {

  public function new() {

    describe("build macro", {
      it("should work with syntax @protect", {
        var control = [];

        try @protect {
          protected: {
            control.push("prot");
            throw "needed";
          },
          cleanup: control.push("clean")
        }
        catch (e: String) { if ("needed" != e) control.push("wrong"); }

        control.should.containExactly(["prot", "clean"]);
      });

      it("should expand nested prot-in-prot", {
        var control = [];

        try @protect {
          protected: @protect {
            protected: {
              throw "out!";
            },
            cleanup: {
              control.push("inner");
            }
          },
          cleanup: {
            control.push("outer");
          }
        }
        catch (e: String) { if ("out!" != e) control.push("wrong"); }
        
        control.should.containExactly(["inner", "outer"]);
      });

      it("should observe scope syntax", {
        var control = [];

        try {
          @scope control.push("two");
          control.push("one");
        }

        control.should.containExactly(["one", "two"]);
      });

    });
  }
}
