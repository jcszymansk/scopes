package scopes;

import buddy.*;
using buddy.Should;

import haxe.io.Eof;

class ExceptionTest extends BuddySuite implements ScopeSyntax {

  public function new() {

    describe("exception guards", {
      it("should select by exception", {
        var control = [];

        try Scope.withExits({
          @scope(String) control.push(4);
          control.push(1);
          throw "test";
          control.push(2);
        })
        catch (e: String) control.push(3);

        control.should.containExactly([1, 4, 3]);
          
      });

      it("should bypass other exceptions", {
        var control = [];

        try Scope.withExits({
          @scope(String) control.push(1);
          control.push(2);
          throw Date.now();
          control.push(3);
        }) catch (e: Date) control.push(4);


        control.should.containExactly([2, 4]);
      });

      it("should allow parametrized guards", {
        
        var control: Array<Dynamic> = [];

        try Scope.withExits({
          @scope(@as(s) String) control.push(s);
          control.push(1);
          throw "a";
          control.push(2);
        })
        catch (e: String) control.push(3);

        control.should.containExactly(([1, "a", 3]:Array<Dynamic>));

      });

      it("should allow path guards", {
        
        var control = [];

        try Scope.withExits({
          @scope(haxe.io.Error) control.push(4);
          control.push(1);
          throw haxe.io.Error.Overflow;
          control.push(2);
        })
        catch (e: String) control.push(3)
        catch (e: haxe.io.Error) control.push(5)
        catch (e: Dynamic) {}

        control.should.containExactly([1, 4, 5]);

      });

      it("should quell handler exceptions", {
        
        var control: Array<Dynamic> = [];

        try Scope.withExits({
          @SCOPE(@as(s) String) {  control.push(s); throw Date.now(); control.push("no"); }
          control.push("one");
          throw "test";
          control.push("two");
        })
        catch (e: String) control.push("three");

        control.should.containExactly(["one", "test", "three"]);

      });

      it("should @quell exceptions", {
        var control = [];

        try Scope.withExits({
          control.push("one");
          @quell throw "two";
          control.push("three");
        }) catch (e: String) control.push(e);

        control.should.containExactly(["one", "three"]);
      });

      it("should @quell exceptions by type", {
        var control = [];

        try Scope.withExits({
          control.push("one");
          @quell(String) throw "two";
          @quell(String, Date) throw Date.now();
          control.push("three");
        }) catch (e: String) control.push(e);

        control.should.containExactly(["one", "three"]);
      });

      it("should bypass un-@quell'ed exceptions", {
        var control = [];

        try Scope.withExits({
          control.push("one");
          @quell(Date) throw "two";
          control.push("three");
        }) catch (e: String) control.push(e);

        control.should.containExactly(["one", "two"]);
      });

      it("should @quell imported exceptions", {
        var control = [];

        try Scope.withExits({
          control.push("one");
          @quell(Eof) throw new Eof();
          control.push("three");
        }) catch (e: Eof) control.push("four");

        control.should.containExactly(["one", "three"]);
      });

      it("should @quell path exceptions", {
        var control = [];

        try Scope.withExits({
          control.push("one");
          @quell(haxe.io.Error) throw haxe.io.Error.Overflow;
          control.push("three");
        }) catch (e: Eof) control.push("four");

        control.should.containExactly(["one", "three"]);
      });


    });



  }

}
