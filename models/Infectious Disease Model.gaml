/***
* Name: InfectiousDiseaseModel
* Author: xuanyu
* Description: 
* Agent movement: Random choose building as target
* Sperading method: Get infected if stay in building with other who has disease
* Tags: Null
***/

model InfectiousDiseaseModel

global {
	int nb_people <- 500;
	int nb_infected_init <- 5;
	int staying_time <- 60;
	file roads_shapefile <- file("../includes/ncku_road.shp");
	file buildings_shapefile <- file("../includes/ncku_building.shp");
	geometry shape <- envelope(roads_shapefile);
	graph road_network;
	int nb_people_infected <- nb_infected_init update: people count (each.is_infected);
	int nb_people_not_infected <- nb_people - nb_infected_init update: nb_people - nb_people_infected;
	float infected_rate update: nb_people_infected/length(people);
	
	init {
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);
		create building from: buildings_shapefile;
		create people number:nb_people {
			speed <- 5.0 #km/#h;
			location <- any_location_in(one_of(building));
			target <- any_location_in(one_of(building));
		}
		ask nb_infected_init among people {
			is_infected <- true;
		}
	}
	reflex end_simulation when: infected_rate = 1.0 {
		do pause;
	}
}

species people skills:[moving]{
	bool is_infected <- false;
	point target;
	int staying_counter;
	
	reflex move when: target != nil{
		do goto target: target on: road_network;
		if (location = target) {
			target <- nil;
		} 
	}
	
	aspect default{
		draw circle(10) color:is_infected ? #red : #green;
	}
}

species road {
	geometry display_shape <- shape + 2.0;
	aspect default {
		draw display_shape color: #black depth: 3.0;
	}
}

species building {
	float height <- 10#m + rnd(10) #m;
	int nb_infected_in_building <- 0;
	int nb_people_in_building <- 0;
	aspect default {
		draw shape color:nb_infected_in_building = 0 ? #gray : #red depth: height;
	}
	reflex let_people_enter {
		ask (people inside self where ((each.target = nil) and (each.staying_counter = 0))){
			myself.nb_people_in_building <- myself.nb_people_in_building + 1;
			if(is_infected){
				if(myself.nb_infected_in_building = 0){
					ask (people inside myself where (each.is_infected = false)){
						is_infected <- true;						
					}
					myself.nb_infected_in_building <- myself.nb_people_in_building;
				}else{
					myself.nb_infected_in_building <- myself.nb_infected_in_building + 1;
				}
			}else{
				if(myself.nb_infected_in_building != 0){
					is_infected <- true;
					myself.nb_infected_in_building <- myself.nb_infected_in_building + 1;
				}
			}
		}
	}
	reflex let_people_leave {
		ask (people inside self where (each.target = nil)){
			staying_counter <- staying_counter + 1;
			if(staying_counter >= staying_time){
				if(is_infected){
					myself.nb_infected_in_building <- myself.nb_infected_in_building - 1;
				}
				staying_counter <- 0;
				target <- any_location_in(one_of(building));
				myself.nb_people_in_building <- myself.nb_people_in_building - 1;
			}
		}
	}
}

experiment main_experiment type:gui{
	parameter "Nb people in total" var: nb_people;
	parameter "Nb people infected at init" var: nb_infected_init;
	parameter "Staying time" var: staying_time;
	output {
		monitor "Infected people rate" value: infected_rate;
		display map_3D type: opengl {
			species road ;
			species people;			
			species building  transparency: 0.5;
		}
		display chart refresh: every(10#cycles) {
			chart "Disease spreading" type: series style: spline {
				data "susceptible" value: nb_people_not_infected color: #green marker: false;
				data "infected" value: nb_people_infected color: #red marker: false;
			}
		}
	}
}

