package scopes;

import buddy.*;
using buddy.Should;

import scopes.Protect;

class ReturnTest extends BuddySuite {

  public function new() {

    describe("returning from protected and cleanup blocks", {
      it("should run cleanup when prot returns value", {
        var control = [];

        var run = function() {
          Protect.protect({
            return "value";
          },
          {
            control.push("clean");
          });
          return "whatever";
        };

        control.push(run());

        control.should.containExactly(["clean", "value"]);


      });

      it("should run cleanup when prot returns void", {
        var control = [];

        var run = function() {
          Protect.protect({
            return;
          },{
            control.push("clean");
          });

          throw "unexpected";
        }

        run();

        control.should.containExactly(["clean"]);

      });

      it("should ignore return and throw whatever cleanup throws", {
        var control = [];

        var run = function() {
          Protect.protect({
            return "ignore";
          },
          {
            throw "thrown";
          });
          throw "unexpected";
        };

        run.should.throwValue("thrown");

      });

      it("should handle return in try/catch(Dynamic) in prot", {
        var control = [];

        var fun = function() {
          Protect.protect({
            try return 1
            catch (e: Dynamic) {}
          }, {
            // nothing
          });

          return 7;
        }

        fun().should.be(1);
      });

      it("should handle conditional return in try/catch(Dynamic) in prot", {
        var control = [];

        var fun = function() {
          Protect.protect({
            try if (true) return 1
            catch (e: Dynamic) {}
          }, {
            // nothing
          });

          return 2;
        }

        fun().should.be(1);
      });
    });


    describe("escape from protected block in a loop", {
      it("should execute cleanup when break-ing", {
        var control = [];

        for (ind in 0...3) {
          Protect.protect({
            if (ind == 2) break;
            control.push(Std.string(ind));
          }, 
          {
            control.push(Std.string(ind) + "a");
          });
        }

        control.should.containExactly(["0", "0a", "1", "1a", "2a"]);
      });
      it("should execute cleanup when continue-ing", {
        var control = [];

        for (ind in 0...3) {
          Protect.protect({
            if (ind % 2 == 0) continue;
            control.push(Std.string(ind));
          }, {
            control.push(Std.string(ind) + "a");
          });


        }

        control.should.containExactly(["0a", "1", "1a", "2a"]);
      });

    });




  }
}
