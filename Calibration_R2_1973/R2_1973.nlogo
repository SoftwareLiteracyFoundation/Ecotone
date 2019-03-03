;
; Model Notes:
;  See the NOTES section below.
;
; NetLogo Notes:
;   Be mindful of the agent context (patch, turtle...) when
;   setting variables, make sure the desired context is current.
;
;   Variable names are CASE INSENSITIVE.
;
;   __reload at the command center to reload a model from disk.
;
;   To change the memory available to the JVM, edit NetLogo.cfg
;   and set [JVMOptions] -Xmx1024m as described here:
;   ccl.northwestern.edu/netlogo/docs/faq.html#howbig
;
extensions [ gis time ]

globals [
  VegMap        ; GIS vector map
  GaugeZones    ; GIS vector map for Stage & Salinity timeseries mapping
  date          ; time object github.com/colinsheppard/time/
  start-date_t  ; time object
  end-date_t    ; time object

  Stage.data           ; time-series data object
  Salinity.gauge.data  ; time-series data object
  MeanSeaLevel.data    ; time-series data object
  timeseries.output    ; time-series data object

  patch_raster  ; output GIS raster with patch variable (numeric)

  ;---------------------------------------------------------
  ; agentsets of patches from initial species (1973)
  ;---------------------------------------------------------
  Red_Mangrove_patches    Buttonwood_patches      Cypress_patches
  Swamp_Bay_patches       Sawgrass_patches        Spikerush_patches
  Muhly_Grass_patches     Red_Bay_patches         Sweet_Bay_patches
  Pond_Apple_patches      Willow_patches          Wax_Myrtle_patches
  Open_patches

  Dead_patches
  Model_patches ; patches within 1973 model domain DOMSPP_73 -> species_init

  ;---------------------------------------------------------
  ; agentsets of patches from final species (2015)
  ; Note that these have a wider domain than the 1973 data
  ;--------------------------------------------------------
  Sawgrass_fini_patches   Spikerush_fini_patches   Red_Mangrove_fini_patches

  ; Lists of patch & turtle species to color mappings
  red_list   green_list yellow_list
  brown_list blue_list  pink_list   sky_list

  ; JP Temporary: Patches to output spikerush timeseries
  Patch_timeseries_xy
]
; end globals

; Turtles
breed [ red-mangroves       red-mangrove      ]
breed [ buttonwoods         buttonwood        ]
breed [ cypress             a-cypress         ]
breed [ swamp-bays          swamp-bay         ]
breed [ sawgrass            a-sawgrass        ]
breed [ spikerushs          spikerush         ]
breed [ muhly-grass         a-muhly-grass     ]
breed [ red-bays            red-bay           ]
breed [ sweet-bays          sweet-bay         ]
breed [ pond-apples         pond-apple        ]
breed [ willows             willow            ]
breed [ wax-myrtle          a-wax-myrtle      ]
breed [ open                a-open            ]

turtles-own [ species          ; string of species name
              species_end
              binomen
              max_height
              abundance
              min_abundance
              max_abundance
              cohabit
              salinity_max      ; tolerable salinity
              salinity_max_days ; tolerable period
            ]

patches-own [ ; Computed or time series patch variables
              depth
              days_wet
              days_dry
              salinity           ; current timestep value
              porewater_salinity ;
              salinity_threshold ; set by turtle salinity_max
              salinity_days      ; days maintained above salinity_threshold
              ;phosphorus

              cell_ID      ; Read from GIS VegMap shapefile in setup
              veg_code     ; Read from GIS VegMap shapefile in setup
              description  ; Read from GIS VegMap shapefile in setup
              matrix       ; Read from GIS VegMap shapefile in setup
              elevation    ; Read from GIS VegMap shapefile in setup

              reason_died  ; String reason the patch turtles died
              day_died     ;

              UTM_min_x    ; Set from gis:envelope-of patch
              UTM_max_x    ;
              UTM_min_y    ;
              UTM_max_y    ;

              stage_gauge    ; Read from GIS GaugeZones shapefile in setup
              salinity_gauge ; Read from GIS GaugeZones shapefile in setup

              ; These are initialized when the patches are created from the
              ; GIS shapefile, then transfered to the initial turtle
              ; sprouted on the patch
              species_init       ; Read from GIS VegMap shapefile in setup
              species_fini       ; Read from GIS VegMap shapefile in setup
              binomen_fini       ; Read from GIS VegMap shapefile in setup
              abundance_fini     ; Read from GIS VegMap shapefile in setup
              min_abundance_fini ; Read from GIS VegMap shapefile in setup
              max_abundance_fini ; Read from GIS VegMap shapefile in setup
              max_height_fini    ; Read from GIS VegMap shapefile in setup
              cohabit_fini       ; Read from GIS VegMap shapefile in setup
            ]

;------------------------------------------------------------------------------
to setup
;------------------------------------------------------------------------------
  clear-all
  reset-ticks

  set-default-shape turtles "dot"
  set-color-lists ; local function to populate species : color mappings

  ; Set time objects for start/end from interface start-date & end-date
  set start-date_t time:create start-date
  set end-date_t   time:create end-date
  ; Set date (time) object and link to model ticks at days-per-tick
  set date time:anchor-to-ticks start-date_t days-per-tick "day"

  print "Loading hydro data..."
  set Stage.data time:ts-load "EDEN_R2_Subset_StageNAVDcm_1973_2017.csv"
  set Salinity.gauge.data time:ts-load "TR_SaltFill_1973-1-1_2018-7-18.csv"
  set MeanSeaLevel.data time:ts-load "Elev_MSL_1973-1-1_2017-12-31.csv"

  print "Loading GIS shapefile..." ; Load GIS data into VegMap & GaugeZones
  load-gis-shapefile

  print "Initialize patches..."
  init-patch-species-agensets
  init-patch-species-fini-agensets
  init-patches
  count-patch-agentsets

  print "Sprout turtles..."
  sprout-turtles-on-patches

  print "Finish setup..."
  finish-patch-setup

  if record-timeseries [ init-timeseries-output ]

  print "Done"
end

;------------------------------------------------------------------------------
to go
;------------------------------------------------------------------------------
  output-print time:show date "yyyy-MM-dd"

  update-patch-depth-salinity

  ; Process species specific patch agentsets for environmental impact
  go-sawgrass
  go-spikerush
  go-wax-myrtle
  ;go-red-mangrove ; Can't die... sprouted in go-propagation
  ;go-cypress
  ;go-buttonwood
  ;go-willow
  ;go-red-bay

  ; Process dead patches for succession
  go-propagation

  if record-timeseries [ record-timeseries-output ]

  tick ; increment time by +1, see days-per-tick

  if time:is-after date end-date_t [

    ; Additional end of run succussion (optional)
    final-propagation

    if record-timeseries [ time:ts-write timeseries.output timeseries-file ]

    let results compare-fini-simulation

    stop
  ]
end

;-------------------------------------------------------------------------
to go-propagation
;-------------------------------------------------------------------------
  ask Dead_patches [

    let new-growth              true
    let mangrove-boundary-patch false

    ;---------------------------------------------------------
    ; JP Model-specific replacement along the southern bondary
    ;---------------------------------------------------------
    if member? pycor [ 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17
                       25 26 45 52 67 ] [
        if (pycor = 0 ) or
         (pycor = 1  and member? pxcor [34 35 36 37 38 39 40 41 42 43] ) or
         (pycor = 2  and member? pxcor [44 45 46 47 48 49 50] )          or
         (pycor = 3  and member? pxcor [51 52 53 54 55 56 57 58 59 60])  or
         (pycor = 4  and member? pxcor [61 62 63 64 65 66 67 68] )       or
         (pycor = 5  and member? pxcor [69 70 71 72 73 74 75 76] )       or
         (pycor = 6  and member? pxcor [77 78 79 80 81 82 83 84 85] )    or
         (pycor = 7  and member? pxcor [86 87 88 89 90 91 92 93 94] )    or
         (pycor = 8  and member? pxcor [96 97 98 99 100 101 102]    )    or
         (pycor = 9  and member? pxcor [103 104 105 106 107 108 109 110 111]) or
         (pycor = 10 and member? pxcor [112 113 114 115 116 117 118 119]) or
         (pycor = 11 and member? pxcor [120 121 122 123 124 125 126 127]) or
         (pycor = 12 and member? pxcor [128 129 130 131 132 133 134
                                        135 136 137 138]) or
         (pycor = 13 and member? pxcor [139 140 141 142 143 144 145 146 147]) or
         (pycor = 14 and member? pxcor [148 149 150]) or
         (pycor = 15 and member? pxcor [151]) or
         (pycor = 16 and member? pxcor [151]) or
         ;(pycor = 17 and member? pxcor [152]) or
         ;(pycor = 25 and member? pxcor [156]) or
         (pycor = 26 and member? pxcor [157]) or
         (pycor = 45 and member? pxcor [169]) or
         (pycor = 52 and member? pxcor [173]) or
         (pycor = 67 and member? pxcor [183])

        [
          set mangrove-boundary-patch true
        ]
    ]

    ; Get agent set of neighboring species
    let neighbor_species no-turtles

    ask neighbors [ ; query 4 adjacent patches, "neighbors" for all 8
      if count turtles-here > 0 [ ; agentset of turtles on this patch
          ; add turtle from this patch to neighbor_species
          set neighbor_species (turtle-set neighbor_species one-of turtles-here)
      ]
    ]

    ; Accumulate the fitness for each neighbor_species
    ; Species with highest cumulative fitness is selected for propagation
    let sawgrass_cum_fitness  0
    let spikerush_cum_fitness 0
    let mangrove_cum_fitness  0

    ;let i 0
    ; Fitness for each species in neighbor_species
    ask neighbor_species [
      ; Absolutely Crazy syntax to simply find out if the neighbor_species
      ; element (myself) is a specific breed... [breed] is a list?
      if any? (red-mangroves-on patch-here) with [ breed = [breed] of myself ] [
        set mangrove_cum_fitness mangrove_cum_fitness + mangrove_fitness
      ]
      if any? (spikerushs-on patch-here) with [ breed = [breed] of myself ] [
        set spikerush_cum_fitness spikerush_cum_fitness + spikerush_fitness
      ]
      if any? (sawgrass-on patch-here) with [ breed = [breed] of myself ] [
        set sawgrass_cum_fitness sawgrass_cum_fitness + sawgrass_fitness
      ]
      ; JP: Add willows, wax-myrtle, muhly-grass, buttonwood...
    ]

    ; Edge cases where cumulative sums are equal
    if sawgrass_cum_fitness = spikerush_cum_fitness [
      ifelse 50 < random 100 [
        set sawgrass_cum_fitness  sawgrass_cum_fitness - 0.1
      ][
        set spikerush_cum_fitness spikerush_cum_fitness - 0.1
      ]
    ]
    if sawgrass_cum_fitness = mangrove_cum_fitness [
      ifelse 50 < random 100 [
        set sawgrass_cum_fitness sawgrass_cum_fitness - 0.1
      ][
        set mangrove_cum_fitness mangrove_cum_fitness - 0.1
      ]
    ]
    if spikerush_cum_fitness = mangrove_cum_fitness [
      ifelse 50 < random 100 [
        set spikerush_cum_fitness spikerush_cum_fitness - 0.1
      ][
        set mangrove_cum_fitness mangrove_cum_fitness - 0.1
      ]
    ]

    ; Determine species to sprout
    let growth_species ""

    ifelse ( sawgrass_cum_fitness  +
             spikerush_cum_fitness +
             mangrove_cum_fitness ) > 0.05 [

      let max_fitness max ( list sawgrass_cum_fitness
                                 spikerush_cum_fitness
                                 mangrove_cum_fitness )

      ifelse max_fitness = sawgrass_cum_fitness [
        set growth_species "Sawgrass"
      ][
      ifelse max_fitness = mangrove_cum_fitness [
        set growth_species "Red Mangrove"
      ][
      if max_fitness = spikerush_cum_fitness [
        set growth_species "Spikerush"
      ]]]
    ][
      ; No neighbors with fitness > 0.05
      ; Allow a "seed" propagaton from the species_init on this patch
      ; Environmental conditions are checked below
      set growth_species species_init
    ]

    ;if salinity > 1 [ print (word "(" pxcor " " pycor ") S: " salinity " "
    ;                         name_fit " " fitness ) ]

    ; Check conditions as to whether or not new growth actually occurs
    ; Note that success is checking 1 - P since it assumes new-growth is true
    ifelse mangrove-boundary-patch or growth_species = "Red Mangrove" [
      if mangrove-success < random 100 [ set new-growth false ]
      ; if water depth is too deep, the propagule doesn't establish
      if depth > depth-propagule [ set new-growth false ]
      ;if salinity < 2            [ set new-growth false ]
    ] [
    ifelse growth_species = "Spikerush" [
      if spikerush-success < random 100 [ set new-growth false ]
      if days_wet < spikerush-days-wet  [ set new-growth false ]
    ] [
    ifelse growth_species = "Sawgrass" [
      if sawgrass-success < random 100 [ set new-growth false ]
      if depth > sawgrass-depth-min    [ set new-growth false ]
    ] [
      ; growth_species is not in the list
      set new-growth false
    ] ] ]

    if new-growth [
      ; Apparently can't pass in reference to global *_patches or
      ; breed-specific sprout arguments
      ; NetLogo UGLY semantics for a switch : case statement.
      ifelse mangrove-boundary-patch or growth_species = "Red Mangrove" [
        sprout-red-mangroves 1
        ; add this patch to the appropriate agentset
        set Red_Mangrove_patches (patch-set Red_Mangrove_patches self)
      ] [
      ifelse growth_species = "Spikerush" [
        sprout-spikerushs 1

        ask turtles-here [
          set salinity_max      spikerush-salinity-threshold
          set salinity_max_days spikerush-salt-days
        ]
        set salinity_threshold spikerush-salinity-threshold

        set Spikerush_patches (patch-set Spikerush_patches self)
      ] [
      ifelse growth_species = "Sawgrass" [
        sprout-sawgrass 1

        ask turtles-here [
          set salinity_max      sawgrass-salinity-threshold
          set salinity_max_days sawgrass-salt-days
        ]
        set salinity_threshold sawgrass-salinity-threshold

        set Sawgrass_patches (patch-set Sawgrass_patches self)
      ] [
        ; unused else
      ] ] ] ; UGLY semantics for a switch : case statement.

      let patch_color black
      ask turtles-here [
        if species = 0 [
          set species        species_name ; species_name reporter
          set abundance      10
          set min_abundance  10
          set max_abundance  90
          set max_height     30
          set cohabit        "NA"
          set patch_color    species_color species ; species_color reporter
          set color          patch_color
        ]
      ]

      set pcolor patch_color

      set Dead_patches other Dead_patches ; remove from Dead_patches
    ] ; if new-growth

    set neighbor_species no-turtles

  ] ; ask Dead_patches
end

;-------------------------------------------------------------------------
to necrosis [ plants reason ] ; patch context
;-------------------------------------------------------------------------
  set pcolor white
  ask plants [ die ]
  set day_died time:show date "yyyy-MM-dd"
  set reason_died reason
end

;-------------------------------------------------------------------------
to go-sawgrass
;-------------------------------------------------------------------------
; Sawgrass – Cladium jamaicense and Cypress - Taxodium distichum
; Occurs in areas with water continuously aboveground for 6-11 months per year.
; Maximum water depths below 3 ft.
; Cannot survive more than 3 weeks of porewater salinity above 1 psu
; Fire adapted species, resprouts quickly, return interval 2-12 years.
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Sawgrass_patches [

    let plants sawgrass-here ; plants agentset of sawgrass on this patch

    if count plants > 0 [
      ; Guassian of days_wet to determine death by hydroperiod
      ; The range is [0, 365] days, value is N( days_wet, 15 )
      let days_wet_ min ( list 365
                          max ( list 0 random-normal days_wet 15 ) )

      ; Get copy of turtle-context variable salinity_max_days
      let salinity_max_days_ 0
      ask one-of plants [ set salinity_max_days_ salinity_max_days ]

      ; Test for plant death
      let death  false
      let reason ""

      if depth > sawgrass-depth-max [
        set reason ( word "depth > " sawgrass-depth-max " cm" )
        set death true
      ]

      if not death [
        if salinity_days > salinity_max_days_ [
          set reason ( word "salinity_days > " salinity_max_days_ )
          set death true
        ]
      ]

      if death [
        necrosis plants reason
        ; store dead patches in local dead_patches_
        set dead_patches_ (patch-set dead_patches_ self)
      ]
    ] ; if count plants > 0
  ] ; ask Sawgrass_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Sawgrass_patches
    ask dead_patches_ [ set Sawgrass_patches other Sawgrass_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to go-spikerush
;-------------------------------------------------------------------------
; Eleocharis cellulosa = spikerush (mostly, there are 2 or 3 other
;   species in this genus which tend to co-occur)
; Predominates areas where continuous freshwater hydroperiod is >2 years,
;   but where depths are shallow (less than 2 ft).
; Most marsh plants will outcompete Eleocharis in conditions other
;   than very long/shallow hydroperiods.
; My impression is that this species will not survive more than 3 weeks
;   if porewater salinity is above 3 psu.
; Fire does not occur in areas where this plant is dominant.
; Being colonized by mangrove, so probably has a tidal signal
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Spikerush_patches [

    let plants spikerushs-here

    if count plants > 0 [
      ; Gaussian of days_wet and days_dry to determine death
      ; The range is [0, 1000] days, value is N( days_dry, 15 )
      let days_dry_ min ( list 1000
                          max ( list 0 random-normal days_dry 10 ) )

      ; Get copy of turtle-context variable salinity_max_days
      let salinity_max_days_ 0
      ask one-of plants [ set salinity_max_days_ salinity_max_days ]

      ; Test for plant death
      let death  false
      let reason ""

      if depth > spikerush-depth-max [
        set reason ( word "depth > " spikerush-depth-max " cm" )
        set death true
      ]
      if not death [
        if days_dry_ > spikerush-days-dry [
          set reason ( word "days_dry > " spikerush-days-dry )
          set death true
        ]
      ]
      if not death [
        if salinity_days > salinity_max_days_ [ set reason "salinity_days"
                                                set death true ]
      ]

      if death [
        necrosis plants reason
        ; store dead patches in local dead_patches_
        set dead_patches_ (patch-set dead_patches_ self)
      ]

    ] ; if count plants > 0
  ] ; ask Spikerush_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Spikerush_patches
    ask dead_patches_ [ set Spikerush_patches other Spikerush_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to go-wax-myrtle
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Wax_Myrtle_patches [

    let plants wax-myrtle-here

    if count plants > 0 [
      ; Process environmental interaction
      ; Gaussian of days_wet and days_dry to determine death
      ; The range is [0, 1000] days, value is N( days_dry, 15 )
      let days_wet_ min ( list 1000
                          max ( list 0 random-normal days_wet 15 ) )

      ; Test for plant death
      let death  false
      let reason ""

      if depth > wax-myrtle-depth-max [
        set reason ( word "depth > " wax-myrtle-depth-max " cm" )
        set death true
      ]
      if not death [
        if days_wet_ > wax-myrtle-days-wet [
          set reason ( word "days_wet > " wax-myrtle-days-wet )
          set death true
        ]
      ]
      if not death [
        if salinity_days > 10 [ set reason "salinity_days"
                                set death true ]
      ]

      if death [
        necrosis plants reason
        ; store dead patches in local dead_patches_
        set dead_patches_ (patch-set dead_patches_ self)
      ]
    ] ;if count plants > 0
  ] ; ask Wax_Myrtle_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Wax_Myrtle_Bay_patches
    ask dead_patches_ [
      set Wax_Myrtle_patches other Wax_Myrtle_patches

      ; Wax Myrtle seems to all transform to Swamp Bay
      sprout-swamp-bays 1
      set Swamp_Bay_patches (patch-set Swamp_Bay_patches self)

      let patch_color black
      ask turtles-here [
        if species = 0 [
          set species     species_name ; species_name reporter
          set patch_color species_color species ; species_color reporter
          set color       patch_color
        ]
      ]
      set pcolor patch_color
    ]
    ; Add dead_patches_ to global Dead_patches agentset
    ; set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to go-red-mangrove
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Red_Mangrove_patches [

    let plants red-mangroves-here

    if count plants > 0 [
      ; Process environmental interaction

      ; Test for plant death
      let death  false
      let reason ""

      ; if reason_to_die [ set death true  set reason "xyz" ]

      if death [
        necrosis plants reason
        ; store dead patches in local dead_patches_
        set dead_patches_ (patch-set dead_patches_ self)
      ]
    ]
  ] ; ask Red_Mangrove_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Red_Mangrove_patches
    ask dead_patches_ [ set Red_Mangrove_patches other Red_Mangrove_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to go-buttonwood
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Buttonwood_patches [

    let plants buttonwoods-here

    if count plants > 0 [
      ; Process environmental interaction

      ; Test for plant death
      let death  false
      let reason ""

      ; if reason_to_die [ set death true  set reason "xyz" ]

      if death [
        necrosis plants reason
        ; store dead patches in local dead_patches_
        set dead_patches_ (patch-set dead_patches_ self)
      ]
    ]
  ] ; ask Buttonwood_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Buttonwood_patches
    ask dead_patches_ [ set Buttonwood_patches other Buttonwood_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to go-cypress
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Cypress_patches [

    let plants cypress-here

    if count plants > 0 [
      ; Process environmental interaction

      ; Test for plant death
      let death  false
      let reason ""

      ; if reason_to_die [ set death true  set reason "xyz" ]

      if death [
        necrosis plants reason
        ; store dead patches in local dead_patches_
        set dead_patches_ (patch-set dead_patches_ self)
      ]
    ]
  ] ; ask Cypress_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Cypress_patches
    ask dead_patches_ [ set Cypress_patches other Cypress_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to go-willow
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Willow_patches [

    let plants willows-here

    if count plants > 0 [
      ; Process environmental interaction

      ; Test for plant death
      let death  false
      let reason ""

      ; if reason_to_die [ set death true  set reason "xyz" ]

      if death [
        necrosis plants reason
        ; store dead patches in local dead_patches_
        set dead_patches_ (patch-set dead_patches_ self)
      ]
    ]
  ] ; ask Willow_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Red_Bay_patches
    ask dead_patches_ [ set Willow_patches other Willow_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to go-red-bay
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Red_Bay_patches [

    let plants red-bays-here

    if count plants > 0 [
      ; Process environmental interaction

      ; Test for plant death
      let death  false
      let reason ""

      ; if reason_to_die [ set death true  set reason "xyz" ]

      if death [
        necrosis plants reason
        ; store dead patches in local dead_patches_
        set dead_patches_ (patch-set dead_patches_ self)
      ]
    ]
  ] ; ask Red_Bay_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Red_Bay_patches
    ask dead_patches_ [ set Red_Bay_patches other Red_Bay_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to update-patch-depth-salinity
;-------------------------------------------------------------------------
  ask Model_patches [
    ; Set patch water depth. Stage is the Stage.data reporter
    ; stage_gauge is read from GIS GaugeZones shapefile in setup
    set depth ( Stage stage_gauge ) - elevation

    ; Accumulate hydroperiod (days_wet) and days_dry
    ifelse depth > 0 [ set days_wet days_wet + days-per-tick set days_dry 0 ]
                     [ set days_dry days_dry + days-per-tick set days_wet 0 ]
  ]

  ; Patches with elevation below mean offset sea level elevation
  let elev_patches Model_patches with [ elevation < ElevationMSL_Offset ]

  ; JP Model specific limit on progression of porewater front
  ; Patches with elevation below -20 cm NAVD and east of UTM_x 537600
  let east_elev_patches elev_patches with [ elevation < -20 and
                                            utm_max_x > 537600 ]
  ; Patches within ~ 1.5 km of mangrove lines, moves north with MSL
  let ymax UTM_MSL_ymax ; UTM_MSL_ymax reporter
  let msl_patches elev_patches with [ utm_max_y < ymax ]
  ; Add patches of east_elev below the -20 cm contour
  set msl_patches (patch-set msl_patches east_elev_patches )

  ; Patches below MSL elevation and with depth < depth-no-porewater
  let porewater_patches msl_patches with [ depth < depth-no-porewater ]

  ask porewater_patches [
    ifelse porewater_salinity = 0 [
      set porewater_salinity 1
    ][
    ifelse porewater_salinity = 1 [
      set porewater_salinity 2
    ][
    if porewater_salinity = 2 [
      set porewater_salinity 3
    ] ] ]
  ]

  ; Patches below MSL elevation and with depth > depth-no-porewater
  let no_porewater_patches msl_patches with [ depth >= depth-no-porewater ]
  ; Freshwater head resets porewater_salinity (and salinity) to 0
  ask no_porewater_patches [ set porewater_salinity 0
                             set salinity 0 ]

  ask msl_patches [
    ; Get salinity from gauge
    let gauge_salinity Salinity.from.gauge salinity_gauge
    ; Set patch salinity to max of MSL porewater_salinity and gauge
    set salinity max ( list porewater_salinity gauge_salinity )

    ; Accumulate or reset days with salinity above salinity threshold
    ; Note that patch salinity_threshold was set to the initial turtle
    ; salinity_max when the sawgrass was sprouted in sprout-turtles-on-patches
    ifelse salinity >= salinity_threshold [
      set salinity_days salinity_days + days-per-tick
    ][
      set salinity_days 0
    ]
  ]
end

;-------------------------------------------------------------------------
to init-timeseries-output
;-------------------------------------------------------------------------
  ; JP : Temporary Hardcoded to write spikerush timeseries
  ; 36 49               spikerush to sawgrass
  ; 48 98               sawgrass to spikerush
  ; 42 92, 52 105       spikerush
  ; 13 65, 35 48, 42 90 spikerush
  ; 47 99               sawgrass to spikerush
  set Patch_timeseries_xy [ [13 65] [35 48] [42 90] [47 99] ]

  let var_names (list "Wet_13_65"  "Dry_13_65"  "Salt_13_65"
                      "Wet_35_48"  "Dry_35_48"  "Salt_35_48"
                      "Wet_42_90"  "Dry_42_90"  "Salt_42_90"
                      "Wet_47_99"  "Dry_47_99"  "Salt_47_99")

  set timeseries.output ( time:ts-create var_names )
end

;-------------------------------------------------------------------------
to record-timeseries-output
;-------------------------------------------------------------------------
  ; JP Hardcoded for patches defined in init-timeseries-output
  let wet1 0   let dry1 0   let salt1 0
  let xy item 0 Patch_timeseries_xy
  ask patch first xy last xy [
    set wet1  days_wet
    set dry1  days_dry
    set salt1 salinity
  ]

  let wet2 0  let dry2 0  let salt2 0
  set xy item 1 Patch_timeseries_xy
  ask patch first xy last xy [
    set wet2  days_wet
    set dry2  days_dry
    set salt2 salinity
  ]

  let wet3 0  let dry3 0  let salt3 0
  set xy item 2 Patch_timeseries_xy
  ask patch first xy last xy [
    set wet3  days_wet
    set dry3  days_dry
    set salt3 salinity
  ]

  let wet4 0  let dry4 0  let salt4 0
  set xy item 3 Patch_timeseries_xy
  ask patch first xy last xy [
    set wet4  days_wet
    set dry4  days_dry
    set salt4 salinity
  ]

  let row-vals ( sentence date wet1 dry1 salt1 wet2 dry2 salt2
                          wet3 dry3 salt3 wet4 dry4 salt4 )

  time:ts-add-row timeseries.output row-vals
end

;-------------------------------------------------------------------------
to final-propagation
;-------------------------------------------------------------------------
  let sawgrass-success_   sawgrass-success
  let sawgrass-depth-min_ sawgrass-depth-min
  let spikerush-success_  spikerush-success
  let spikerush-days-wet_ spikerush-days-wet
  let mangrove-success_   mangrove-success

  set sawgrass-success   50
  set sawgrass-depth-min 200
  set spikerush-success  50
  set spikerush-days-wet 0
  set mangrove-success   50

  let n_final 0
  while [ n_final < n-final-propagation ] [
    go-propagation
    set n_final n_final + 1
  ]

  set sawgrass-success   sawgrass-success_
  set sawgrass-depth-min sawgrass-depth-min_
  set spikerush-success  spikerush-success_
  set spikerush-days-wet spikerush-days-wet_
  set mangrove-success   mangrove-success_
end

;-------------------------------------------------------------------------
to init-patches
; Must be called After load-gis-shapefile and init-patch-species-agensets
;-------------------------------------------------------------------------
  print "Initializing patches, convert elevation from ft to cm..."
  ask patches [
    ifelse cell_ID > 0 [ ; patch had Cell_ID from the GIS shapefile
      ifelse is-number? elevation [ set elevation elevation * 30.48 ]
                                  [ set elevation "" ]
      set salinity_threshold 100
      set salinity_days      0

      if draw-patches [
        ; apply colors to patches based on species_init
        set pcolor species_color species_init ; species_color is a reporter
      ]
    ]
    [ ; No Cell_ID from the GIS shapefile
      set pcolor           grey ;
      set cell_ID          0    ; Replace NaN set by gis:apply-coverage
      set veg_code         ""   ;
      set description      ""   ;
      set species_init     ""   ;
      set species_fini     ""   ;
      set elevation        ""   ;
      set matrix           ""   ;
      set stage_gauge      "None" ;
      set salinity_gauge   "None" ;
    ]

    ; Check that stage_gauge is not a relic NaN from the GIS import
    ; This will happen if the GaugeZone map excludes patches
    if not is-string? stage_gauge [
       type self print description
       print stage_gauge
      ; Netlogo NaN test is this crazy comparison chain...
      if not ( stage_gauge > 0 or stage_gauge < 0 or stage_gauge = 0) [
        type "No stage_gauge at " type self print description
        set stage_gauge    "None"
        set salinity_gauge "None"
      ]
    ]

    let envelope_coord patch_gis_coordinates
    ; envelope_coord = [minimum-x maximum-x minimum-y maximum-y]
    set UTM_min_x item 0 envelope_coord
    set UTM_max_x item 1 envelope_coord
    set UTM_min_y item 2 envelope_coord
    set UTM_max_y item 3 envelope_coord
  ] ; ask patches
end

;-------------------------------------------------------------------------
to finish-patch-setup
; Must be called After sprout-turtles-on-patches
;------------------------------------------------------------------------
  ; Get sawgrass salinity limits from GUI sliders, store in turtle variable
  ; setup sawgrass salinity_max to match patch salinity_threshold
  ask Sawgrass_patches [
    ask sawgrass-here [
      set salinity_max      sawgrass-salinity-threshold
      set salinity_max_days sawgrass-salt-days
    ]
    set salinity_threshold sawgrass-salinity-threshold
  ]

  ; Get spikerush salinity limits from GUI sliders, store in turtle variable
  ; setup salinity_max to match patch salinity_threshold
  ask Spikerush_patches [
    ask spikerushs-here [
      set salinity_max      spikerush-salinity-threshold
      set salinity_max_days spikerush-salt-days
    ]
    ; spikerush 0.25, 0.5, 0.75 quartiles for R2_subset 2006-2016
    ;            201  349  596 days wet
    ;              6   17   45 days dry
    set salinity_threshold  spikerush-salinity-threshold
    set days_wet            500  ; init hydroperiod
  ]

  set Model_patches patches with [ species_init != "" and is-number? elevation ]
end

;-------------------------------------------------------------------------
to sprout-turtles-on-patches
;-------------------------------------------------------------------------
  ask Red_Mangrove_patches   [ sprout-red-mangroves   1 [ init-turtle-vars ] ]
  ask Buttonwood_patches     [ sprout-buttonwoods     1 [ init-turtle-vars ] ]
  ask Cypress_patches        [ sprout-cypress         1 [ init-turtle-vars ] ]
  ask Swamp_Bay_patches      [ sprout-swamp-bays      1 [ init-turtle-vars ] ]
  ask Sawgrass_patches       [ sprout-sawgrass        1 [ init-turtle-vars ] ]
  ask Spikerush_patches      [ sprout-spikerushs      1 [ init-turtle-vars ] ]
  ask Muhly_Grass_patches    [ sprout-muhly-grass     1 [ init-turtle-vars ] ]
  ask Red_Bay_patches        [ sprout-red-bays        1 [ init-turtle-vars ] ]
  ask Sweet_Bay_patches      [ sprout-sweet-bays      1 [ init-turtle-vars ] ]
  ask Pond_Apple_patches     [ sprout-pond-apples     1 [ init-turtle-vars ] ]
  ask Wax_Myrtle_patches     [ sprout-wax-myrtle      1 [ init-turtle-vars ] ]
  ask Willow_patches         [ sprout-willows         1 [ init-turtle-vars ] ]
end

;-------------------------------------------------------------------------
to init-turtle-vars
;-------------------------------------------------------------------------
  ; Copies patch variables read from GIS to sprouted turtles
  ; Called in the context of a patch sprout-breed [ turtle commands ]
  set species        species_init
  set species_end    species_fini
  set binomen        binomen_fini
  set abundance      abundance_fini
  set min_abundance  min_abundance_fini
  set max_abundance  max_abundance_fini
  set max_height     max_height_fini
  set cohabit        cohabit_fini

  set color species_color species ; species_color is a reporter
end

;-------------------------------------------------------------------------
to init-patch-species-agensets
;-------------------------------------------------------------------------
  ; Collect species-defined patches into appropriate agent sets
  ; from the species_init field in the GIS DB file for each patch
  set Red_Mangrove_patches patches with
      [ member? species_init[ "Red Mangrove" ] ]

  set Buttonwood_patches patches with
      [ member? species_init[ "Buttonwood" ] ]

  set Cypress_patches patches with
      [ member? species_init[ "Cypress" ] ]

  set Swamp_Bay_patches patches with
      [ member? species_init[ "Swamp Bay" ] ]

  set Sawgrass_patches patches with
      [ member? species_init[ "Sawgrass" ] ]

  set Spikerush_patches patches with
      [ member? species_init[ "Spikerush" ] ]

  set Muhly_Grass_patches patches with
      [ member? species_init[ "Muhly Grass" ] ]

  set Red_Bay_patches patches with
      [ member? species_init[ "Red Bay" ] ]

  set Sweet_Bay_patches patches with
      [ member? species_init[ "Sweet Bay" ] ]

  set Pond_Apple_patches patches with
      [ member? species_init[ "Pond Apple" ] ]

  set Wax_Myrtle_patches patches with
      [ member? species_init[ "Wax Myrtle" ] ]

  set Willow_patches patches with
      [ member? species_init[ "Willow" ] ]

  set Open_patches patches with
      [ member? species_init[ "Open" ] ]

  set Dead_patches no-patches
end

;-------------------------------------------------------------------------
to init-patch-species-fini-agensets
;-------------------------------------------------------------------------
  ; Collect species-defined patches into appropriate agent sets
  ; from the species_fini field in the GIS DB file for each patch.
  ; Note that the 1973 coverage has less data than the 2015 layer.
  ; The 2015 data will have empty DOMSPP_73 (species_init "")

  ; Get agent set of all Spikerush from the 2015 layer
  set Spikerush_fini_patches patches with [ member? species_fini["Spikerush"] ]
  ; Remove patches that don't have a 1973 species_init
  set Spikerush_fini_patches Spikerush_fini_patches with [ species_init != "" ]

  set Sawgrass_fini_patches patches with [ member? species_fini["Sawgrass"] ]
  set Sawgrass_fini_patches Sawgrass_fini_patches with [ species_init != "" ]

  set Red_Mangrove_fini_patches patches with
      [ member? species_fini["Red Mangrove" ] ]
  set Red_Mangrove_fini_patches Red_Mangrove_fini_patches with
      [ species_init != "" ]
end

;-------------------------------------------------------------------------
to count-patch-agentsets
;-------------------------------------------------------------------------
  let N count Red_Mangrove_patches
  if N > 0 [ print ( word N " patches of Red_Mangrove" ) ]

  set N count Buttonwood_patches
  if N > 0 [ print ( word N " patches of Buttonwood" ) ]

  set N count Cypress_patches
  if N > 0 [ print ( word N " patches of Cypress" ) ]

  set N count Swamp_Bay_patches
  if N > 0 [ print ( word N " patches of Swamp_Bay" ) ]

  set N count Sawgrass_patches
  if N > 0 [ print ( word N " patches of Sawgrass" ) ]

  set N count Spikerush_patches
  if N > 0 [ print ( word N " patches of Spikerush" ) ]

  set N count Muhly_Grass_patches
  if N > 0 [ print ( word N " patches of Muhly_Grass" ) ]

  set N count Red_Bay_patches
  if N > 0 [ print ( word N " patches of Red_Bay" ) ]

  set N count Sweet_Bay_patches
  if N > 0 [ print ( word N " patches of Sweet_Bay" ) ]

  set N count Pond_Apple_patches
  if N > 0 [ print ( word N " patches of Pond_Apple" ) ]

  set N count Wax_Myrtle_patches
  if N > 0 [ print ( word N " patches of Wax_Myrtle" ) ]

  set N count Willow_patches
  if N > 0 [ print ( word N " patches of Willow" ) ]

  set N count Open_patches
  if N > 0 [ print ( word N " patches of Open" ) ]

end

;-------------------------------------------------------------------------
to set-color-lists
;-------------------------------------------------------------------------
  ; setup patch & turtle color mapping to species
  ;    black, gray, white, red, orange, brown, yellow, green,
  ;    lime, turquoise, cyan, sky, blue, violet, magenta, pink
  set red_list    [ "Black Mangrove" "Red Mangrove" "White Mangrove" ]
  set green_list  [ "Sawgrass" "Muhly Grass" "Fan Palm" "Arrowhead"
                    "Black Rush" "Beakrush""Morning Glory" ]
  set yellow_list [ "Spikerush" "Cypress" "Cattail" ]
  set brown_list  [ "Buttonwood" "Buttonbush" "Seaside Oxeye"
                    "Paurotis Palm" "Saltwort" "Sea Grape" ]
  set blue_list   [ "Mahogany" "Hardwood Hammock" "Swamp Woodland"
                    "Hardwood Woodland" "Willow" "Wax Myrtle"
                    "Cocoplum" "Gumbo Limbo" "Red Bay" "Sweet Bay"
                    "Swamp Bay" "Pond Apple" "Poisonwood" ]
  set pink_list   [ "Mixed Shrub" "Broadleaf Marsh" "Swamp Shrubland" ]
  set sky_list    [ "Open" ]
end

;-------------------------------------------------------------------------
to load-gis-shapefile
;-------------------------------------------------------------------------
  gis:load-coordinate-system  "../R2_GIS/R2_subset_1973.prj"
  set VegMap gis:load-dataset "../R2_GIS/R2_subset_1973.shp"
  gis:set-world-envelope gis:envelope-of VegMap

  set GaugeZones gis:load-dataset "../R2_GIS/R2_1973_Gauge_Zones.shp"

  ; JP: What happens when a GIS Cell_ID is represented in more
  ;     than one row of the DB table????
  ;     For example, the following Cell_IDs have multiple species:
  ;
  ; 1282637	CSBGc	Red Bay
  ; 1282637	CSBGc	Pond Apple
  ; 1282637	CSBGc	Sweet Bay
  ;
  ; 1419354	CSBTGc	Buttonwood
  ; 1419354	CSBTGc	Red Mangrove
  ;
  ; 1612842	SMXX	Black Mangrove
  ; 1612842	SMXX	Red Mangrove
  ; 1612842	SMXX	White Mangrove
  ;
  ; observer> show patches with [cell_id = 1282637]
  ; observer: (agentset, 2 patches)
  ; observer> show patches with [cell_id = 1419354]
  ; observer: (agentset, 0 patches)
  ; observer> show patches with [cell_id = 1612842]
  ; observer: (agentset, 1 patch)

  print "Loading patch variables from GIS..."
  ; gis will set patch variables outside the imported shapefile to NaN...
  gis:apply-coverage VegMap "CELL_ID"     cell_ID
  gis:apply-coverage VegMap "VEG_CODE"    veg_code
  gis:apply-coverage VegMap "DESCRIPTIO"  description
  gis:apply-coverage VegMap "NAVD88_FT"   elevation
  gis:apply-coverage VegMap "MATRIX"      matrix
  ; These are read from the GIS shapefile, but transfered to turtles
  gis:apply-coverage VegMap "SPECIES"     species_fini
  gis:apply-coverage VegMap "DOMSPP_73"   species_init
  gis:apply-coverage VegMap "BINOMEN"     binomen_fini
  gis:apply-coverage VegMap "ABUNDANCE"   abundance_fini
  gis:apply-coverage VegMap "MINABUNDAN"  min_abundance_fini
  gis:apply-coverage VegMap "MAXABUNDAN"  max_abundance_fini
  gis:apply-coverage VegMap "MAXHEIGHT"   max_height_fini
  gis:apply-coverage VegMap "COHABIT"     cohabit_fini

  ; Station names for stage and salinity gauges/timeseries
  gis:apply-coverage GaugeZones "STAGE"      stage_gauge
  gis:apply-coverage GaugeZones "SALINITY_G" salinity_gauge
end

;-------------------------------------------------------------------------
to save-gis-raster
;-------------------------------------------------------------------------
  ; gis:patch-dataset patch-variable
  ; Reports a new raster whose cells correspond directly to NetLogo patches,
  ; and whose cell values consist of the values of the given patch variable
  ask patches [
    ; Seems to only work for numeric values, not strings
    set patch_raster gis:patch-dataset salinity
  ]

  gis:store-dataset patch_raster gis-raster-file
end

;-------------------------------------------------------------------------
to record-patch-output
;-------------------------------------------------------------------------
  if file-exists? patch-output-file [ file-delete patch-output-file ]
  file-open  patch-output-file
  file-print "Cell_ID,pxcor,pycor,depth,salinity,species,day_died,reason_died"

  ask patches [
    ;if day_died != 0 and reason_died != 0 [
    if Cell_ID > 0 [
      let species_name_ ""
      if any? turtles-here [
        ask one-of turtles-here [ set species_name_ species ]
      ]

      file-print( word int Cell_ID "," pxcor "," pycor ","
                  precision depth 1 "," salinity ","
                  species_name_ "," day_died "," reason_died )
    ]
  ]
  file-close
end

;-------------------------------------------------------------------------
to plot-horizontal-line [ y ]
;-------------------------------------------------------------------------
  plot-pen-up
  plotxy 0 y
  plot-pen-down
  plotxy plot-x-max y

  plot-pen-up
  plotxy 0 0
  plot-pen-down
end

;-------------------------------------------------------------------------
; Report comparison between fini patches and simulation
;-------------------------------------------------------------------------
to-report compare-fini-simulation

  ; All patches with breed, no matter where in the domain
  let sawgrass_patches_  Model_patches with [ count sawgrass-here > 0 ]
  let spikerush_patches_ Model_patches with [ count spikerushs-here > 0 ]
  let mangrove_patches_  Model_patches with [ count red-mangroves-here > 0 ]

  let sawgrass_count  count sawgrass_patches_
  let spikerush_count count spikerush_patches_
  let mangrove_count  count mangrove_patches_

  ; All final (2015) patches by species
  let sawgrass_fini_patches_  Model_patches with [ species_fini = "Sawgrass" ]
  let spikerush_fini_patches_ Model_patches with [ species_fini = "Spikerush"]
  let mangrove_fini_patches_ Model_patches with [ species_fini = "Red Mangrove"]

  let sawgrass_fini_count  count sawgrass_fini_patches_
  let spikerush_fini_count count spikerush_fini_patches_
  let mangrove_fini_count  count mangrove_fini_patches_

  ; Count number of patches that match pxcor pycor and species
  let sawgrass_match 0
  ask sawgrass_patches_ [
    let x pxcor
    let y pycor
    ask sawgrass_fini_patches_ [
      if x = pxcor and y = pycor [
        set sawgrass_match sawgrass_match + 1
        stop
      ]
    ]
  ]

  let spikerush_match 0
  ask spikerush_patches_ [
    let x pxcor
    let y pycor
    ask spikerush_fini_patches_ [
      if x = pxcor and y = pycor [
        set spikerush_match spikerush_match + 1
        stop
      ]
    ]
  ]

  let mangrove_match 0
  ask mangrove_patches_ [
    let x pxcor
    let y pycor
    ask mangrove_fini_patches_ [
      if x = pxcor and y = pycor [
        set mangrove_match mangrove_match + 1
        stop
      ]
    ]
  ]

  let sawgrass_success  precision (sawgrass_match  / sawgrass_fini_count ) 2
  let spikerush_success precision (spikerush_match / spikerush_fini_count) 2
  let mangrove_success  precision (mangrove_match  / mangrove_fini_count ) 2

  let patch_total sawgrass_fini_count + mangrove_fini_count
  let match_total sawgrass_match      + mangrove_match ; + spikerush_match
  let total_success precision (match_total / patch_total) 2

  print(word count Dead_patches " dead patches. Model match: " total_success   )
  print(word sawgrass_count  " patches of Sawgrass remain: "  sawgrass_success )
  print(word spikerush_count " patches of Spikerush remain: " spikerush_success)
  print(word mangrove_count  " patches of Mangrove remain: "  mangrove_success )

  ; report fraction of patches that match x,y in fini_patches
  let match_list (list sawgrass_success mangrove_success
                       spikerush_success total_success )
  ;report ( match_list )
  report ( total_success )
end

;-------------------------------------------------------------------------
; Report the species name from a turtle (myself)
;-------------------------------------------------------------------------
to-report species_name ; myself is a breed

  let name_ ""

  ; NetLogo UGLY semantics for a switch : case statement...
  ifelse any? sawgrass-on      myself [ set name_ "Sawgrass"     ] [
  ifelse any? red-mangroves-on myself [ set name_ "Red Mangrove" ] [
  ifelse any? spikerushs-on    myself [ set name_ "Spikerush"    ] [
  ifelse any? wax-myrtle-on    myself [ set name_ "Wax Myrtle"   ] [
  ifelse any? willows-on       myself [ set name_ "Willow"       ] [
  ifelse any? red-bays-on      myself [ set name_ "Red Bay"      ] [
  ifelse any? swamp-bays-on    myself [ set name_ "Swamp Bay"    ] [
  if     any? muhly-grass-on   myself [ set name_ "Muhly Grass"  ]
  ] ] ] ] ] ] ]

  report name_
end

;-------------------------------------------------------------------------
; Logistic fitness function
;-------------------------------------------------------------------------
to-report mangrove_fitness
  report 1 / ( 1 + exp( -5 * ( salinity - 1.6 ) ) )
end

to-report spikerush_fitness
  report 1 / ( 1 + exp( -4 * ( 2.1 - salinity ) ) )
end

to-report sawgrass_fitness
  report 1 / ( 1 + exp( -6 * ( 1.2 - salinity ) ) )
end

;-------------------------------------------------------------------------
; Report the color from the color list that holds the species name
;-------------------------------------------------------------------------
to-report species_color [ species_ ] ; species_ is a string "Sawgrass"

  let color_ grey

  ; black, gray, white, red, orange, brown, yellow, green,
  ; lime, turquoise, cyan, sky, blue, violet, magenta, pink

  ; NetLogo UGLY semantics for a switch : case statement...
  ifelse member? species_ green_list   [ set color_ green  ] [
  ifelse member? species_ blue_list    [ set color_ blue   ] [
  ifelse member? species_ yellow_list  [ set color_ yellow ] [
  ifelse member? species_ red_list     [ set color_ red    ] [
  ifelse member? species_ sky_list     [ set color_ sky    ] [
  ifelse member? species_ brown_list   [ set color_ brown  ] [
  if     member? species_ pink_list    [ set color_ pink   ]
  ] ] ] ] ] ]

  report color_
end

;-------------------------------------------------------------------------
; Report GIS (UTM 17R) coordinates for a patch
; arguments are patch x, y coordinates
; returns list [minimum-x maximum-x minimum-y maximum-y] from gis:envelope-of
;-------------------------------------------------------------------------
to-report patch_gis_coordinates
  let this-patch patch pxcor pycor
  let envelope_coord gis:envelope-of this-patch
  report envelope_coord
end

;-------------------------------------------------------------------------
;
;-------------------------------------------------------------------------
;to-report Hydroperiod
;  let hydropatch patch pxcor pycor
;  let dw 0
;  ask hydropatch [ set dw days_wet ]
;  report dw
;end

;-------------------------------------------------------------------------
; patch x y argument
;-------------------------------------------------------------------------
to-report PatchDepth [ x y ]
  let This.depth 0
  ask patch x y [
      set This.depth depth
  ]
  report This.depth
end

;-------------------------------------------------------------------------
; station argument is column name from the Stage.data
; csv file: Cell_14_191, Cell_17_188, Cell_8_172, ...
;-------------------------------------------------------------------------
to-report Stage [ station ]
  ifelse station = "None" [
    report 0
  ]
  [
    let This.stage time:ts-get Stage.data date station
    report This.stage
  ]
end

;-------------------------------------------------------------------------
; station argument is column name from the Salinity.gauge.data
; csv file: BK, LM, MK, TR
;-------------------------------------------------------------------------
to-report Salinity.from.gauge [ station ]
  ifelse station = "None" [
    report 0
  ]
  [
    let salinity-psu time:ts-get Salinity.gauge.data date station
    report salinity-psu
  ]
end

;-------------------------------------------------------------------------
; Reporter for Elev_MSL_1973-1-1_2017-12-31.csv
;-------------------------------------------------------------------------
to-report ElevationMSL_Offset
  let slr-mangrove time:ts-get MeanSeaLevel.data date "Elevation_SLR"
  report slr-mangrove - msl-offset ; msl-offset to mangrove elev from msl
end

;-------------------------------------------------------------------------
; Reporter for UTM_min_y distance from MSL for porewater
; Min UTM_y is 2792500 for MSL porewater in 1975
; UTM_y max for porewater will increase at deltaMSL * 1500m/13.5cm
;-------------------------------------------------------------------------
to-report UTM_MSL_ymax
  let slr-mangrove time:ts-get MeanSeaLevel.data date "Elevation_SLR"
  let deltaMSL slr-mangrove + 27.6
  report ( slr-mangrove + 2792500 ) + ( deltaMSL * 110 )
end
@#$#@#$#@
GRAPHICS-WINDOW
409
10
1044
349
-1
-1
3.0
1
10
1
1
1
0
0
0
1
0
208
0
109
1
1
1
ticks
150.0

BUTTON
5
10
78
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
6
46
69
79
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

INPUTBOX
91
47
200
107
start-date
1975-1-1
1
0
String

INPUTBOX
91
110
200
170
end-date
2015-12-31
1
0
String

PLOT
723
526
1044
658
Salinity
Time ticks
PSU
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"TR" 1.0 0 -2674135 true "" "plot Salinity.from.gauge \"Salinity_ppt\""

PLOT
410
352
1044
524
Depth
Time ticks
Depth (cm)
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Patch 17 5" 1.0 0 -2674135 true "" "plot PatchDepth 17 5"
"Patch 7 107" 1.0 0 -13345367 true "" "plot PatchDepth 7 107"
"Patch 180 107" 1.0 0 -6459832 true "" "plot PatchDepth 180 107"
"Patch 140 25" 1.0 0 -10899396 true "" "plot PatchDepth 140 25"
"Patch 31 50" 1.0 0 -5825686 true "" "plot PatchDepth 31 50"
"Depth 0" 1.0 0 -16777216 true "" "plot-horizontal-line 0"

SWITCH
81
10
214
43
draw-patches
draw-patches
0
1
-1000

INPUTBOX
6
84
86
144
days-per-tick
30.0
1
0
Number

INPUTBOX
76
363
211
423
GIS-raster-file
salinity-raster
1
0
String

BUTTON
9
373
72
406
Raster
save-gis-raster\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
76
299
211
359
patch-output-file
patch-output.csv
1
0
String

SLIDER
226
258
401
291
sawgrass-depth-min
sawgrass-depth-min
0
30
20.0
1
1
NIL
HORIZONTAL

SLIDER
234
455
401
488
spikerush-days-wet
spikerush-days-wet
0
800
730.0
5
1
NIL
HORIZONTAL

SLIDER
233
330
400
363
sawgrass-salinity-threshold
sawgrass-salinity-threshold
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
233
365
400
398
sawgrass-salt-days
sawgrass-salt-days
5
30
20.0
1
1
NIL
HORIZONTAL

SLIDER
232
563
402
596
spikerush-salinity-threshold
spikerush-salinity-threshold
0
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
231
600
402
633
spikerush-salt-days
spikerush-salt-days
5
70
20.0
1
1
NIL
HORIZONTAL

OUTPUT
410
527
718
658
24

SLIDER
224
491
402
524
spikerush-depth-max
spikerush-depth-max
30
200
80.0
10
1
NIL
HORIZONTAL

SLIDER
232
527
402
560
spikerush-days-dry
spikerush-days-dry
50
200
170.0
10
1
NIL
HORIZONTAL

SLIDER
235
222
401
255
sawgrass-success
sawgrass-success
0
100
33.0
1
1
NIL
HORIZONTAL

SLIDER
223
85
401
118
depth-no-porewater
depth-no-porewater
-10
30
2.0
1
1
cm
HORIZONTAL

SLIDER
223
48
400
81
msl-offset
msl-offset
0
20
2.0
1
1
cm
HORIZONTAL

SLIDER
234
419
401
452
spikerush-success
spikerush-success
0
100
33.0
1
1
NIL
HORIZONTAL

SLIDER
223
134
401
167
mangrove-success
mangrove-success
0
100
33.0
1
1
NIL
HORIZONTAL

SLIDER
223
169
401
202
depth-propagule
depth-propagule
0
50
7.0
1
1
cm
HORIZONTAL

SLIDER
246
10
400
43
n-final-propagation
n-final-propagation
0
100
10.0
1
1
NIL
HORIZONTAL

BUTTON
8
312
71
345
Output
record-patch-output
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
11
185
174
218
record-timeseries
record-timeseries
1
1
-1000

INPUTBOX
10
221
174
281
timeseries-file
spikerush-hydro.csv
1
0
String

SLIDER
226
294
401
327
sawgrass-depth-max
sawgrass-depth-max
50
200
180.0
10
1
NIL
HORIZONTAL

SLIDER
30
454
206
487
wax-myrtle-depth-max
wax-myrtle-depth-max
0
200
180.0
1
1
NIL
HORIZONTAL

SLIDER
30
488
206
521
wax-myrtle-days-wet
wax-myrtle-days-wet
0
800
370.0
10
1
NIL
HORIZONTAL

@#$#@#$#@
# NOTES

## WHAT IS IT?
A dynamic ecotone transformation model. Patches correspond to the 50 x 50 m vegetation classification map developed by Ruiz et al. (2017).  Turtles represent vegetation species.

## HOW IT WORKS
The Ruiz et al. (2017) vegetation map specifying vegetation codes for each patch has been transformed into a species-centric vegetation map with species binomem explicity identified on each patch. Turtles are initially sprouted on patches according to the GIS vegetation map. 

Environmental data are informed through the time extension, with daily mean water levels and salinities provided as timeseries input to patch agents.  The link between timeseries and patches is specified in a the Gauge_zones.shp GIS layer.

Agentsets of patches with dominant species are used to track and optimally operate agent actions.

## HOW TO USE IT
Setup button initializes the model.

Run button executes the model. 

## NETLOGO FEATURES
Netlogo time extension is used for environmental data input.
Netlog gis extension is used to initialze the patches and turtles. 

## REFERENCES
Ruiz et al., (2017) The Everglades National Park and Big Cypres National Preserve Vegetation Mapping Project, Interim Report–Southeast Saline Everglades (Region 2). Everglades National Park Natural Resource Report NPS/SFCN/NRR—2017/1494. Pablo L. Ruiz, Helena C. Giannini, Michelle C. Prats, Craig P. Perry, Michael A. Foguer, Alejandro Arteaga Garcia, Robert B. Shamblin, Kevin R. T. Whelan, Mary-Joe Hernandez, August 2017.

### Domain
The world is a grid of (118, 273) patches corresponding to a spatial domain of 5,900 x 13,650 m in 50 m patches. The domain wraps hoizontally, but not vertically. The origin is (0,0) in the lower left corner.

Patch elevations are NAVD88 (cm).  Water elevation data from EDEN are NAVD88 (cm).  Water elevation data from hydrographic stations have been previously converted from NGVD29 (ft) to NAVD88 (cm).

### GIS Input
The GIS Shapefile DB initial values are all set into patch variables, ones that are turtle specific (species, binomen, abundance, height...) are transfered to turtle variables in sprout-turtles-on-patches.

Mapping of Species to Veg_Code is in SpeciesFilled.csv

VegMap Shapefile DB fields:
```
------------------------------------
Vegetation  515
Cell_ID     1265362
Veg_Code    MFGcSD
Species     Sawgrass
Binomen     Cladium jamaicense
Abundance   70
MinAbundan  50
MaxAbundan  100
MaxHeight   2
CoHabit     NA
Matrix      NA
Descriptio  Short Sawgrass Marsh-Dense
PolyArea    200.00
NGVD29_Ft   1.298
NAVD88_Ft   -0.2081 <- Loaded to patch elevation in load-gis-shapefile
------------------------------------
```

Stage and Salinity data sources for each patch are specified in Gauge_zones.shp with the Salinity_G and Stage DB fields. Data are read from the corresponding column in the data .csv file.

Gauge Zone Shapefile DB fields:
```
------------------------------------
Salinity_G LM
Stage      Cell_5_183
Zone       EDEN
------------------------------------
```

### Environmental Data
Stage data [DailyStage_NAVD_cm_1994-6-1_2017-5-15.csv] are extracted from EDEN cells if they overlap with the model domain, or, are extracted from Data4EVER hydro stations and converted to NAVD88 (cm). EDEN water surfaces are elevation in centimeters NAVD88.

Salinity data [DailySalinityFilled_1994-6-1_2017-5-15.csv] are from MOI research: Research/old/JMSE_SLR/DailySalinityFilled_1994-6-1_2016-12-31.Rdata with 2017 appended from Data4Ever.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

dot
false
0
Circle -7500403 true true 90 90 120

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="msl-offset_depth-porewater" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>compare-fini-simulation</metric>
    <steppedValueSet variable="depth-no-porewater" first="-5" step="1" last="10"/>
    <steppedValueSet variable="msl-offset" first="0" step="1" last="10"/>
  </experiment>
  <experiment name="Export View" repetitions="20" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>export-view (word "R2_1973_Result-" date-and-time ".png")</final>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
