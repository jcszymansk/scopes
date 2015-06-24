package scopes;

import buddy.*;
import scopes.Protect;
using buddy.Should;

class MainTest extends BuddySuite {

  public function new() {

    describe("basic tests without returns", {
      it("should run both protected and cleanup", {
        var control = [];

        Protect.protect(
          {
            control.push("prot");
          },
          {
            control.push("clean");
          }
        );

        control.should.containExactly(["prot", "clean"]);


      });

      it("should run cleanup when protected throws", {
        var control = [];

        try Protect.protect({
          throw "protected";
        },
        {
          control.push("clean");
        })
        catch (e: String) {}

        control.should.containExactly(["clean"]);
      });

      it("should rethrow exception when protected throws", {
        
        var control = [];

        try Protect.protect({
          throw "control11";
        },
        {})
        catch (e: String) control.push(e) 
        catch (e: Dynamic) {}

        control.should.containExactly(["control11"]);
      });

      it("should lose orig exception when cleanup throws", {
        var control = [];

        try Protect.protect({
          throw "control11";
        }, {
          throw "control22";
        })
        catch (e: String) control.push(e)
        catch (e: Dynamic) {}

        control.should.containExactly(["control22"]);
      });
    });

  }

}
