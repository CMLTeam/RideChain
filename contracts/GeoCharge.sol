pragma solidity 0.4.23;

/// @dev Contract GeoCharge allows for automatic charge of the vehicle
///      when it passes one of the predefined checkpoints
contract GeoCharge {
  /// @dev If during the `passedThrough` there was enough funds to
  ///      charge, we store that in `pendingCharges` to be able to charge later
  mapping(address => uint64) public pendingCharges;

  /// @dev Array of checkpoints (latitudes)
  uint32[] public lats;
  /// @dev Array of checkpoints (longitudes)
  uint32[] public lons;
  /// @dev Array of allowed leeways for each checkpoint
  uint32[] public leeways;
  /// @dev Array of charge fees for each checkpoint
  uint64[] public fees;

  /// @dev Owners withdraws funds from the contract and disables the contract
  ///      when it becomes no longer valid due to changes in data - coordinates or fees
  // TODO: develop data update mechanism
  address public owner;

  /// @dev Emitted when vehicle passes through the checkpoint
  /// @dev Charge receipt
  event PassedThrough(
    address vehicle,
    uint32 time,
    uint32 checkpointLat,
    uint32 checkpointLon,
    uint32 leeway,
    uint32 actualLat,
    uint32 actualLon,
    uint64 fee,
    uint64 charged,
    uint64 pendingCharge,
    uint64 totalPendingCharges
  );

  /// @dev creates an instance with the settings specified
  constructor(uint32[] _lats, uint32[] _lons, uint32[] _leeways, uint64[] _fees) public {
    // validate inputs
    require(_lats.length > 0);
    require(_lats.length == _lons.length);
    require(_lats.length == _leeways.length);
    require(_lats.length == _fees.length);

    // set up the contract
    lats = _lats;
    lons = _lons;
    leeways = _leeways;
    fees = _fees;

    // init the owner
    owner = msg.sender;
  }

  /// @dev Used by vehicle if it should send the `passedThrough` transaction
  /// @return zero if checkpoint is not passed, charge fee otherwise
  function isPassingCheckpoint(uint32 lat, uint32 lon) constant public returns (uint64 fee) {
    // iterate over array of checkpoints
    for(uint32 i = 0; i < lats.length; i++) {
      // try to find intersected checkpoint
      if(uint64(lats[i] - lat)**2 + uint64(lons[i] - lon)**2 < uint64(leeways[i])**2) {
        // return its fee on success
        return fees[i];
      }

      // return zero if point not found
      return 0;
    }
  }

  /// @dev Called by vehicle device when it passed close to checkpoint
  // TODO: create batched version to optimize gas costs
  function passedThrough(uint32 lat, uint32 lon) public payable {
    // initial variable states - zeros
    uint32 checkpointLat = 0;
    uint32 checkpointLon = 0;
    uint32 leeway = 0;
    uint64 fee = 0;
    uint64 charged = 0;
    uint64 pendingCharge = 0;

    // how much value we have in this transaction
    uint64 value = uint64(msg.value);
    // overflow check
    require(msg.value == uint256(value));

    // iterate over array of checkpoints
    for(uint32 i = 0; i < lats.length; i++) {
      // try to find intersected checkpoint
      if(uint64(lats[i] - lat)**2 + uint64(lons[i] - lon)**2 < uint64(leeways[i])**2) {
        checkpointLat = lats[i];
        checkpointLon = lons[i];
        leeway = leeways[i];
        fee = fees[i];
        break;
      }
    }

    // if fee is not zero - try to charge
    if(fee > 0) {
      // if we have enough value
      if(value >= fee) {
        // charge full fee
        charged = fee;
      }
      else {
        // otherwise add to pending charges
        pendingCharge = fee;
      }
    }

    // try to consume pending charges if any
    if(value - charged > 0 && pendingCharges[msg.sender] > 0) {
      // if value sent is enough to cover all pending charges
      if(value >= charged + pendingCharges[msg.sender]) {
        // cover them all
        charged += pendingCharges[msg.sender];
      }
      else {
        // otherwise cover only what we have
        charged = value;
      }
    }

    // transfer charge if any
    if(charged > 0) {
      owner.transfer(charged);
    }
    // persist pending charge if any
    if(pendingCharge > 0) {
      pendingCharges[msg.sender] += pendingCharge;
    }

    // send the charge back to vehicle if any
    if(value > charged) {
      msg.sender.transfer(value - charged);
    }

    // emit an event
    emit PassedThrough(msg.sender, uint32(now), checkpointLat, checkpointLon, leeway, lat, lon, fee, charged, pendingCharge, pendingCharges[msg.sender]);
  }

}
