package scopes;

import buddy.*;
using buddy.Should;

class InnerTest extends BuddySuite {

  public function new() {

    describe("inner functions, loops etc.", {
      it("should not escape prot when inner function returns", {
        var control = [];

        var outer = function() Protect.protect({
          var inner = function() {
            return;
          };

          inner();

          control.push("ok");
        },
        {
          // nothing here
        });

        outer();

        control.should.containExactly(["ok"]);

      });

      it("should not escape prot when inner loop breaks", {
        var control = [];

        for (outer in 0...1) {
          Protect.protect({
            for (inner in 0...1) break;

            control.push("ok");
          }, {
            // nothing
          });
        }

        control.should.containExactly(["ok"]);
      });

      it("should not escape prot when inner loop continues", {
        var control = [];

        for (outer in 0...1) {
          Protect.protect({
            for (inner in 0...1) continue;

            control.push("ok");
          },
          {
            // nothing  
          });

        }

        control.should.containExactly(["ok"]);
      });

    });


    describe("prot inside prot", {
      it("should execute all cleanups inside out", {
        var control = [];

        Protect.protect({
          Protect.protect({
            // nothing here
            1;
          }, {
            control.push("inner");
          });
        }, {
          control.push("outer");
        });

        control.should.containExactly(["inner", "outer"]);
      });
    });


  }
}
