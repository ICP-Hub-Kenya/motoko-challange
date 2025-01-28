import Time "mo:base/Time";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import UUID "mo:uuid/UUID";
import Source "mo:uuid/async/SourceV4";

module {
  // Convert an integer to a Nat
  public func intToNat(i : Int) : Nat {
    switch (Nat.fromText(Int.toText(i))) {
      case (null) { Debug.trap("Invalid conversion") };
      case (?n) { n };
    };
  };

  // Get remaining time
  public func getRemTime(from : Time.Time) : Nat {
    let now = Time.now();
    if (now > from) {
      0;
    } else {
      intToNat(from - now);
    };
  };

  // Generate a new UUID
  public func uuid() : async Text {
    let g = Source.Source();
    UUID.toText(await g.new());
  };
};
