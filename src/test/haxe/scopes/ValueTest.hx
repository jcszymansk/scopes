package scopes;

import buddy.*;
using buddy.Should;

class ValueTest extends BuddySuite {

  public function new() {
  
    describe("values/types for prot&coe", {
      it("should return prot's value as expression value", {
        var value: String = Protect.protect({
          "ok";
        },
        {
          "not ok";
        });

        value.should.be("ok");

      });

      it ("should run when prot's value's a void", {

        var control = [];
        
        Protect.protect({
          control.push("been there");
          for (i in 0...1) break;
        },
        {
          control.push("done that");
        });

        control.should.containExactly(["been there", "done that"]);

        
      });

      it("should tolerate basic types of values", {
        var x = Protect.protect({1;}, {2;});

        x.should.be(1);

      });

    });


  }
}
