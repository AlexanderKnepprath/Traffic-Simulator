import java.util.List;

List<Lane> lanes;
List<Vehicle> vehicles;

final int total_track_length = 1500;    // total length of track (including offscreen)

final int num_lanes = 3;                // number of lanes in simulation
final int lane_width = 100;             // width of lanes in simulation

final int num_vehicles = 4;             // number of vehicles in simulation

final double patience_return_rate = 0.1;    // rate at which drivers' patience returns
final int min_merge_interval = 200;         // minimum time delay between merges
final int min_crash_delay = 300;            // minimum time delay until crash is resolved

void setup() {
  noStroke();
  size(1500, 300);
  
  lanes = new ArrayList();
  for (int i = 0; i < num_lanes; ++i) {
    lanes.add(new Lane(i * lane_width, lane_width));
  }
  
  vehicles = generateVehicles(num_vehicles);
}

void draw() {
  background(#AAAAAA);
  
  // draw lanes in background
  for (int i = 0; i < lanes.size(); ++i) {
    lanes.get(i).drawLane();
  }
  
  // update every vehicle's information
  
  for (int i = 0; i < vehicles.size(); ++i) {
    Vehicle vehicle = vehicles.get(i);
    vehicle.tick();
    
    // recover vehicle if crashed
    if (vehicle.isCrashed() && vehicle.crashDelay() == 0) {
      vehicles.remove(vehicle);
    }
    
    // check for other vehicles which may be a hazard
    
    boolean hazardFound = false;
    for (int j = 0; j < vehicles.size(); ++j) {
      
      // check to see if brakes should be applied
      
      Vehicle hazard = vehicles.get(j);
      if (hazard != vehicle                         // ensure hazard vehicle is not this vehicle
          && hazard.getLane() == vehicle.getLane()  // ensure that hazard vehicle is in the same lane as this vehicle
          && hazard.getRearBumperPos() > vehicle.getFrontBumperPos() // ensure hazard vehicle is in front of this vehicle
          && hazard.getRearBumperPos() - vehicle.getFrontBumperPos() < vehicle.getDriver().getAttentiveness() * 200 // if hazard vehicle is too close
          && hazard.getDriver().getSpeed() <= vehicle.getDriver().getSpeed()) { // and hazard is slower
          
        double targetSpeed = hazard.getDriver().getSpeed();
        
        vehicle.changeSpeed(targetSpeed);
        hazardFound = true;
        break;
      }
      
      // check for crashes
      
      if (hazard != vehicle                                                  // if hazard vehicle is not this vehicle
          && hazard.getLane() == vehicle.getLane()                           // and hazard and vehicle are in the same lane
          && vehicle.getFrontBumperPos() >= hazard.getRearBumperPos()         
          && vehicle.getFrontBumperPos() < hazard.getFrontBumperPos()) {     // and vehicle front bumper is between hazard rear and front bumper
          
        vehicle.crash();
        hazard.crash();
      }
    }
    
    if (!hazardFound) {vehicle.changeSpeed(1); } // if there is no hazard, vehicle can reaccelerate.
    
    // consider merges
    
    if (vehicle.getDriver().fullPatience()) {
      vehicle.tryMergeRight();
    }
    
    if (vehicle.getDriver().getPatience() == 0) {
      if (!vehicle.tryMergeLeft() && vehicle.getDriver().getSpeed() == 0) {
        vehicle.tryMergeRight();
      }
    }
    
    // update vehicle's position
    vehicle.moveVehicle();
    // draw vehicle on screen
    vehicle.drawVehicle();
  }
}

List<Vehicle> generateVehicles(int num_vehicles) {
  List<Vehicle> vehicles = new ArrayList();
  int lane = lanes.size() - 1;
  int pos = 0;
  boolean keepGeneratingCars = true;
  for (int i = 0; i < num_vehicles && keepGeneratingCars; ++i) {
    pos += 200;
    if (pos >= total_track_length - 200) {
      --lane;
      pos = 200;
    }
    if (lane < 0) {
      keepGeneratingCars = false;
    }
    vehicles.add(new Vehicle(lane, pos));
  }
  
  return vehicles;
}

//
// Lane class
//

class Lane {
  private int pos, wid;
  
  Lane(int y, int wid) {
    this.pos = y;
    this.wid = wid;
  }
  
  public void drawLane() {
    fill(#FFFFFF);
    rect(0, pos, width, wid/20);
    rect(0, pos + (wid - wid/20), width, wid/20);
  }
}

//
// Vehicle class
//

class Vehicle {
  private int lane, position, radius;
  private double brakePower, accelPower;
  private int red, green, blue;
  private Driver driver;
  
  private boolean crashed;
  private int mergeDelay, crashDelay;
  
  Vehicle(int lane, int position) {
    this.lane = lane;
    this.position = position;
    this.radius = (int)Math.ceil(Math.random() * 10 + 40);
    this.brakePower = 0.15;
    this.accelPower = 0.05;
    
    this.red = (int)(Math.random()*255);
    this.green = (int)(Math.random()*255);
    this.blue = (int)(Math.random()*255);
    
    this.driver = generateRandomDriver();
    
    this.crashed = false;
    this.crashDelay = 0;
    this.mergeDelay = 0;
  }
  
  public Driver getDriver() {
    return driver;
  }
  
  public int getLane() {
    return lane;
  }
  
  public int getFrontBumperPos() {
    int result = position + radius;
    if (result > total_track_length) {result -= total_track_length;}
    return result;
  }
  
  public int getRearBumperPos() {
    int result = position - radius;
    if (result < 0) {result += total_track_length;}
    return result;
  }
  
  public boolean isCrashed() {return this.crashed;}
  public int crashDelay() {return this.crashDelay;}
  
  public void drawVehicle() {
    int center_x = this.position;
    int center_y = (this.lane * lane_width) + lane_width/2;
    
    int corner_x = center_x - radius;
    int corner_y = center_y - lane_width / 4;
    
    int vehicle_length = this.radius * 2;
    int vehicle_width = lane_width / 2;
    
    fill(this.red, this.green, this.blue);
    if (crashed) {
      stroke(#FFFFFF);
      fill(#000000);
    }
    rect(corner_x, corner_y, vehicle_length, vehicle_width);
    noStroke();
  }
  
  public void crash() {
    if (!crashed) {
      this.driver.speed = 0;
      this.crashed = true;
      this.crashDelay = min_crash_delay;
      this.mergeDelay = 0;
    }
  }
  
  public void recover() {
    this.crashed = false;
  }
  
  public void updatePatience() {
    if (!crashed) {
      driver.updatePatience();
    }
  }
  
  public void tick() {
    this.mergeDelay--;
    if (mergeDelay < 0) {mergeDelay = 0;}
    
    this.crashDelay--;
    if (crashDelay < 0) {crashDelay = 0;}
  }
  
  public void changeSpeed(double speed) {
    if (!crashed) {                                      // if we crashed, ignore everything, we can't move.
    
      double new_speed = driver.getSpeed();              // default option is no change
      if (driver.getSpeed() > speed) {                   // if current speed is more than target speed, we must slow down
        new_speed = driver.getSpeed() - this.brakePower; // set new speed the slowest amount we can go to this tick based on brake power
        if (new_speed < speed) {                         // if that's slower than target speed, then we will just set it to the target speed
          new_speed = speed;
        }
      }
      else if (driver.getSpeed() < speed) {              // if current speed is less than target speed, we must speed up
        new_speed = driver.getSpeed() + this.accelPower; // set new speed to fastest amount we can go to this tick based on accel power
        if (new_speed > speed) {                         // if that's faster than target speed, then we will just set it to the target speed
          new_speed = speed;
        }
      }
      
      driver.changeSpeed(new_speed);                     // now tell the driver their new speed
    }
  }
  
  public boolean tryMergeLeft() {
    if (position < radius || position > total_track_length - radius) {return false;} // don't merge at the end of the track
    if (mergeDelay != 0) {return false;} // if we just merged, don't do it again
    if (lane == 0) {return false;} // if there's no lane to merge to, then don't merge
    int targetLane = lane - 1;
    
    // blind spot check
    int rearCheck = getFrontBumperPos() - (int)(radius * 4 * this.driver.attentiveness);
    int frontCheck = getFrontBumperPos() + radius;
    
    for (int i = 0; i < vehicles.size(); ++i) {
      Vehicle hazard = vehicles.get(i);
      int frontBumper = hazard.getFrontBumperPos(); 
      int rearBumper = hazard.getRearBumperPos();
      
      // if there is a car in target lane with either bumper in the zone, do not merge
      if (hazard.getLane() == targetLane
          && ((frontBumper > rearCheck && frontBumper < frontCheck) || (rearBumper > rearCheck && rearBumper < frontCheck))) {return false;}
    }
    
    // otherwise, we can merge!
    this.mergeDelay = min_merge_interval; // set merge countdown
    this.lane = targetLane; // change the lane
    return true;
  }
  
  public boolean tryMergeRight() {
    if (position < 150 || position > total_track_length - 50) {return false;} // don't merge at the end of the track
    if (mergeDelay != 0) {return false;} // if we just merged, don't do it again
    if (lane == num_lanes - 1) {return false;} // if there's no lane to merge to, then don't!
    int targetLane = lane + 1;
    
    // blind spot check
    int rearCheck = getFrontBumperPos() - (int)(radius * 4 * this.driver.attentiveness);
    int frontCheck = getFrontBumperPos() + radius;
    
    for (int i = 0; i < vehicles.size(); ++i) {
      Vehicle hazard = vehicles.get(i);
      int frontBumper = hazard.getFrontBumperPos(); 
      int rearBumper = hazard.getRearBumperPos();
      
      // if there is a car in target lane with either bumper in the zone, do not merge
      if (hazard.getLane() == targetLane
          && (frontBumper > rearCheck && frontBumper < frontCheck) || (rearBumper > rearCheck && rearBumper < frontCheck)) {return false;}
    }
    
    // otherwise, we can merge!
    this.mergeDelay = min_merge_interval; // set merge countdown
    this.lane = targetLane;
    return true;
  }
  
  public void moveVehicle() {
    this.position += (int)(this.driver.getSpeed() * 10);
    updatePatience();
    if (position > total_track_length) {
      position -= total_track_length;
      driver.changeMood();
    }
  }
  
  private Driver generateRandomDriver() {
    double attentiveness = (Math.random() / 3) + 0.66; // random number between 0.66 and 1
    double aggressiveness = Math.random(); // random number between 0 and 1
    double patience = Math.random(); // random number between 0 and 1
    double speed = (Math.random() / 4) + 0.55; // random number between .55 and .8
    
    return new Driver(attentiveness, aggressiveness, patience, speed);
  }
  
}

//
// Driver Class
//

class Driver {
  
  private double base_attentiveness;  // attentiveness monitors how likely the driver will be to notice a hazard
  private double base_aggressiveness; // aggressiveness determines how likely the driver will be to take action when their patience runs out
  private double base_patience;       // the driver's patience will lower when they are forced to slow down for any reason
  private double base_speed;          // the driver's desired speed
  
  private double attentiveness;
  private double aggressiveness;
  private double patience;
  private double speed;
  
  public Driver(double base_attent, double base_aggress, double base_pat, double base_spd) {
    this.base_attentiveness = base_attent;
    this.base_aggressiveness = base_aggress;
    this.base_patience = base_pat;
    this.base_speed = (double)((int)(base_spd * 100))/100; // quantize to nearest 100th
    
    this.attentiveness = this.base_attentiveness;
    this.aggressiveness = this.base_aggressiveness;
    this.patience = this.base_patience;
    this.speed = this.base_speed;    
  }
  
  public void updatePatience() {
    if (this.speed < this.base_speed * 0.9) {                     // if we are going less than 90 percent of the speed we want to
      double d_speed = this.base_speed - this.speed;              // compute the difference in speed
      this.patience -= (this.aggressiveness * d_speed);           // patience wanes if going slow, based off of aggressiveness and speed difference
    } else {                                                      // however, if we are going a speed that we are happy with
      this.patience += (this.base_patience * patience_return_rate); // patience returns at a the determined rate per tick
    }
    
    if (this.patience < 0) {this.patience = 0;}                   // patience can't be < 0 or > base patience
    if (this.patience > this.base_patience) {this.patience = this.base_patience;}
  }
  
  public void changeSpeed(double new_speed) {
    this.speed = new_speed; // update speed
    
    // quantize speed
    int speed_int = (int)(this.speed * 100);
    this.speed = (double)speed_int / 100;
    
    if (this.speed < 0) {this.speed = 0;} // reversing on the freeway causes accidents!
    if (this.speed > this.base_speed) {this.speed = this.base_speed;} // driver should not exceed desired speed
  }
  
  public void changeMood() {
    this.attentiveness = this.base_attentiveness - 0.1 + Math.random()*0.2; // change attentiveness +/- 10 points.
    if (this.attentiveness < 0) {this.attentiveness = 0;}
    else if (this.attentiveness > 1) {this.attentiveness = 1;}
    
    this.aggressiveness = this.base_aggressiveness - 0.1 + Math.random()*0.2; // change agressiveness +/- 10 points.
    if (this.aggressiveness < 0) {this.aggressiveness = 0;}
    else if (this.aggressiveness > 1) {this.aggressiveness = 1;}
  }
  
  public double getAttentiveness() {return this.attentiveness;}
  public double getAggressiveness() {return this.aggressiveness;}
  public double getPatience() {return this.patience;}
  public double getSpeed() {return this.speed;}
  
  public boolean fullPatience() {return this.patience == this.base_patience;}
  
}
