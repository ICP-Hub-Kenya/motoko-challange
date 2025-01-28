import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import List "mo:base/List";

module {
  public type Result<A, B> = Result.Result<A, B>;

  public type Item = {
    title : Text;
    description : Text;
    image : Blob;
    reservePrice : ?Nat;
  };

  public type Bid = {
    price : Nat;
    time : Time.Time;
    originator : Principal;
  };

  public type AuctionId = Text;

  public type AuctionStatus = {
    #Active;
    #Ended;
    #ReservePriceNotMet;
  };

  public type Auction = {
    id : AuctionId;
    item : Item;
    // Used an end time has it better to calculate the remaining time when needed
    endTime : Time.Time;
    bidHistory : List.List<Bid>;
    status : AuctionStatus;
  };

  public type AuctionDetails = {
    item : Item;
    bidHistory : [Bid];
    remainingTime : Nat;
    status : AuctionStatus;
  };

  public type ApiError = {
    #NotFound;
    #NotAuthorized;
    #AuctionEnded;
    #InvalidAmount;
    #ReservePriceNotMet;
  };
};
