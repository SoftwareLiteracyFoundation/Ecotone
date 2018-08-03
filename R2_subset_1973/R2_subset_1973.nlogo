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

  Stage.data    ; time-series data object
  Salinity.data ; time-series data object

  ;---------------------------------------------------------
  ; agentsets of patches from initial species
  ;---------------------------------------------------------
  Black_Mangrove_patches  Red_Mangrove_patches     White_Mangrove_patches
  Buttonwood_patches      Buttonbush_patches       Cypress_patches
  Seaside_Oxeye_patches   Mahogany_patches         Fan_Palm_patches
  Paurotis_Palm_patches   Swamp_Bay_patches        Arrowhead_patches
  Sawgrass_patches        Spikerush_patches        Black_Rush_patches
  Saltwort_patches        Muhly_Grass_patches      Beakrush_patches
  Cattail_patches         Morning_Glory_patches    Cocoplum_patches
  Sea_Grape_patches       Gumbo_Limbo_patches      Red_Bay_patches
  Sweet_Bay_patches       Pond_Apple_patches       Poisonwood_patches
  Mixed_Shrub_patches     Hardwood_Hammock_patches Broadleaf_Marsh_patches
  Swamp_Shrubland_patches Swamp_Woodland_patches   Hardwood_Woodland_patches
  Willow_patches          Wax_Myrtle_patches
  Open_patches            Dead_patches

  ; Lists of patch & turtle species to color mappings
  red_list   green_list blue_list    yellow_list
  brown_list pink_list  magenta_list
]
; end globals

; Turtles
breed [ black-mangroves     black-mangrove    ]
breed [ red-mangroves       red-mangrove      ]
breed [ white-mangroves     white-mangrove    ]
breed [ buttonwoods         buttonwood        ]
breed [ buttonbushs         buttonbush        ]
breed [ cypress             a-cypress         ]
breed [ seaside-oxeyes      seaside-oxeye     ]
breed [ mahoganies          mahogany          ]
breed [ fan-palms           fan-palm          ]
breed [ paurotis-palms      paurotis-palm     ]
breed [ swamp-bays          swamp-bay         ]
breed [ arrowheads          arrowhead         ]
breed [ sawgrass            a-sawgrass        ]
breed [ spikerushs          spikerush         ]
breed [ black-rushs         black-rush        ]
breed [ saltworts           saltwort          ]
breed [ muhly-grass         a-muhly-grass     ]
breed [ beakrushs           beakrush          ]
breed [ cattails            cattail           ]
breed [ morning-glories     morning-glory     ]
breed [ cocoplums           cocoplum          ]
breed [ sea-grapes          sea-grape         ]
breed [ gumbo-limbos        gumbo-limbo       ]
breed [ red-bays            red-bay           ]
breed [ sweet-bays          sweet-bay         ]
breed [ pond-apples         pond-apple        ]
breed [ poisonwoods         poisonwood        ]
breed [ mixed-shrubs        mixed-shrub       ]
breed [ hardwood-hammocks   hardwood-hammock  ]
breed [ broadleaf-marshes   broadleaf-marsh   ]
breed [ swamp-shrublands    swamp-shrubland   ]
breed [ swamp-woodlands     swamp-woodland    ]
breed [ hardwood-woodlands  hardwood-woodland ]
breed [ willows             willow            ]
breed [ wax-myrtle          a-wax-myrtle      ]
breed [ open                a-open            ]

turtles-own [ species
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
              salinity_threshold ; set by turtle salinity_max
              salinity_days      ; days maintained above salinity_threshold
              phosphorus

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

              ; These are not used as patch variables, but are initialized
              ; when the patches are created from the GIS shapefile,
              ; then are transfered to the initial turtle sprouted on
              ; the patch
              species_init       ; Read from GIS VegMap shapefile in setup
              species_fini       ; Read from GIS VegMap shapefile in setup
              binomen_init       ; Read from GIS VegMap shapefile in setup
              abundance_init     ; Read from GIS VegMap shapefile in setup
              min_abundance_init ; Read from GIS VegMap shapefile in setup
              max_abundance_init ; Read from GIS VegMap shapefile in setup
              max_height_init    ; Read from GIS VegMap shapefile in setup
              cohabit_init       ; Read from GIS VegMap shapefile in setup
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
  set Stage.data time:ts-load    "EDEN_R2_Subset_StageNAVDcm_1973_2017.csv"
  set Salinity.data time:ts-load "TR_SaltFill_1973-1-1_2018-7-18.csv"

  print "Loading GIS shapefile..." ; Load GIS data into VegMap & GaugeZones
  load-gis-shapefile

  print "Initialize patches..."
  init-patch-agentsets
  init-patches
  count-patch-agentsets

  print "Sprout turtles..."
  sprout-turtles-on-patches

  print "Finish setup..."
  finish-patch-setup

  print "Done"
end

;------------------------------------------------------------------------------
to go
;------------------------------------------------------------------------------
  output-print time:show date "yyyy-MM-dd"

  ; Process species specific patch agentsets for environmental impact
  go-black-mangrove
  go-buttonwood
  go-red-mangrove
  go-white-mangrove
  go-cypress
  go-sawgrass
  ;go-red-bay
  ;go-poisonwood
  ;go-gumbo-limbo
  go-spikerush
  go-wax-myrtle
  go-willow
  ;go-others

  ; Process dead patches for succession of the listed species
  go-propagation "Red Mangrove" "Rhizophora mangle"

  tick ; increment time by +1, see days-per-tick

  if time:is-after date end-date_t [
    let N count Sawgrass_patches
    print ( word N " patches of Sawgrass remain" )
    set N count Spikerush_patches
    print ( word N " patches of Spikerush remain" )
    set N count Red_Mangrove_patches
    print ( word N " patches of Red Mangrove" )
    set N count Dead_patches
    print ( word N " dead patches" )
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; TDH 20180720 - write data to file at last iteration
  file-delete "ecotone_output.txt"
  file-open "ecotone_output.txt"
    file-print "Cell_ID,day_died,reason_died"
    ask patches
    [ file-print (word Cell_ID "," day_died "," reason_died) ]
  file-close
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    stop
  ]



end

;-------------------------------------------------------------------------
to go-iteration-output [ iteration_number ]
;-------------------------------------------------------------------------
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; TDH 20180726 - record days dry at each iteration. In R, get local optima for each dry event using rle
  file-delete (word "/daysDry/" iteration_number "_" Cell_ID "daysDry_output.txt")
  file-open (word "/daysDry/" iteration_number "_" Cell_ID "daysDry_output.txt")
    file-print "Cell_ID,days_dry,days_wet"
    ask patches
    [ file-print (word Cell_ID "," days_dry "," days_wet) ]
  file-close
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
end

;-------------------------------------------------------------------------
to go-propagation [ adjacent-species adjacent-binomen ]
;-------------------------------------------------------------------------
  ask Dead_patches [

    let new-growth false

    ask neighbors4 [     ; query 4 adjacent patches
      ask turtles-here [ ; agentset of turtles on this patch
        if species = adjacent-species [
          set new-growth true
          stop ; break the ask turtles-here loop
        ]
      ]
      if new-growth [ stop ] ; break the ask neighbors4 loop
    ]

    if new-growth [
      ; Apparently can't pass in reference to global *_patches or
      ; breed-specific sprout arguments
      ; NetLogo UGLY semantics for a switch : case statement.
      ifelse adjacent-species = "Red Mangrove" [
        sprout-red-mangroves 1
        set Red_Mangrove_patches (patch-set Red_Mangrove_patches self)
      ] [
      ifelse adjacent-species = "Black Mangrove" [
        sprout-black-mangroves 1
        set Black_Mangrove_patches (patch-set Black_Mangrove_patches self)
      ] [
      ifelse adjacent-species = "White Mangrove" [
        sprout-white-mangroves 1
        set White_Mangrove_patches (patch-set White_Mangrove_patches self)
      ] [
      ifelse adjacent-species = "Buttonwood" [
        sprout-buttonwoods 1
        set Buttonwood_patches (patch-set Buttonwood_patches self)
      ] [
      ifelse adjacent-species = "Cypress" [
        sprout-cypress 1
        set Cypress_patches (patch-set Cypress_patches self)
      ] [
      ifelse adjacent-species = "Sawgrass" [
        sprout-sawgrass 1
        set Sawgrass_patches (patch-set Sawgrass_patches self)
      ] [
      ifelse adjacent-species = "Spikerush" [
        sprout-spikerushs 1
        set Spikerush_patches (patch-set Spikerush_patches self)
      ] [
      ifelse adjacent-species = "Red Bay" [
        sprout-red-bays 1
        set Red_Bay_patches (patch-set Red_Bay_patches self)
      ] [
      ifelse adjacent-species = "Poisonwood" [
        sprout-poisonwoods 1
        set Poisonwood_patches (patch-set Poisonwood_patches self)
      ] [
      if adjacent-species = "Gumbo Limbo" [
        sprout-gumbo-limbos 1
        set Gumbo_Limbo_patches (patch-set Gumbo_Limbo_patches self)
      ]
      ] ] ] ] ] ] ] ] ] ; UGLY semantics for a switch : case statement.

      ask turtles-here [
        if species = 0 [
          set species        adjacent-species
          set binomen        adjacent-binomen
          set abundance      10
          set min_abundance  10
          set max_abundance  90
          set max_height     30
          set cohabit        "NA"
          set color species_color adjacent-species ; species_color is a reporter
        ]
      ]

      set pcolor species_color adjacent-species
      ; set pcolor orange ; JP REMOVE

      ; add this patch to the appropriate agentset
      ;set adjacent-patchset (patch-set adjacent-patchset self)
      ;set Red_Mangrove_patches (patch-set Red_Mangrove_patches self)

      set Dead_patches other Dead_patches ; remove from Dead_patches
    ] ; if new-growth
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
to go-black-mangrove
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Black_Mangrove_patches [

    let plants black-mangroves-here

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
  ] ; ask Black_Mangrove_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Black_Mangrove_patches
    ask dead_patches_ [ set Black_Mangrove_patches other Black_Mangrove_patches]
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
to go-white-mangrove
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask White_Mangrove_patches [

    let plants white-mangroves-here

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
  ] ; ask White_Mangrove_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from _patches
    ask dead_patches_ [ set White_Mangrove_patches other White_Mangrove_patches]
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
to go-sawgrass
;-------------------------------------------------------------------------
; Sawgrass – Cladium jamaicense and Cypress - Taxodium distichum
; Occurs in areas with water continuously aboveground for 6-11 months per year.
; Maximum water depths below 3 ft.
; Cannot survive more than 3 weeks of porewater salinity above 5 psu
; Fire adapted species, resprouts quickly, return interval 2-12 years.
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Sawgrass_patches [

    let plants sawgrass-here ; plants agentset of sawgrass on this patch

    if count plants > 0 [
      ; Get patch water depth. Stage is the Stage.data reporter
      set depth Stage stage_gauge - elevation

      ; Accumulate and reset the patch hydroperiod variables
      ifelse depth > 0 [ set days_wet days_wet + days-per-tick set days_dry 0 ]
                       [ set days_dry days_dry + days-per-tick set days_wet 0 ]

      ; Guassian of days_dry to determine death
      ; The range is [0, 365] days, value is N( days_dry, 15 )
      let days_dry_ min ( list 365
                          max ( list 0 random-normal days_dry 15 ) )

      ; Get patch salinity
      set salinity Salinity.psu salinity_gauge

      ; Accumulate or reset days with salinity above salinity threshold
      ; Note that patch salinity_threshold was set to the initial turtle
      ; salinity_max when the sawgrass was sprouted in sprout-turtles-on-patches
      ifelse salinity >= salinity_threshold[set salinity_days salinity_days +
                                                              days-per-tick]
                                           [set salinity_days 0 ]

      ; Get copy of turtle-context variable salinity_max_days
      let salinity_max_days_ 0
      ask one-of plants [ set salinity_max_days_ salinity_max_days ]

      ; Test for plant death
      let death  false
      let reason ""

      if depth > 90      [ set reason "depth > 90 cm"   set death true ]
      if days_dry_ > 360 [ set reason "days_dry > 360"  set death true ]
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
;   if porewater salinity is above 5 psu.
; Fire does not occur in areas where this plant is dominant.
; Being colonized by mangrove, so probably has a tidal signal
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Spikerush_patches [

    let plants spikerushs-here

    if count plants > 0 [
      ; Stage is the Stage.data reporter
      set depth Stage stage_gauge - elevation

      ifelse depth > 0 [ set days_wet days_wet + days-per-tick set days_dry 0 ]
                       [ set days_dry days_dry + days-per-tick set days_wet 0 ]

      ; Guassian of days_wet to determine death
      ; The range is [0, 1000000] days, value is N( days_dry, 15 )
      let days_wet_ min ( list 100000
                          max ( list 0 random-normal days_wet 15 ) )

      let days_dry_ min ( list 100000
                          max ( list 0 random-normal days_dry 10 ) )

      set salinity Salinity.psu salinity_gauge / 50 ; JP Bogus scaling

      ; Accumulate or reset days with salinity above salinity threshold
      ; Note that patch salinity_threshold was set to the initial turtle
      ; salinity_max when the sawgrass was sprouted in sprout-turtles-on-patches
      ifelse salinity >= salinity_threshold[set salinity_days salinity_days +
                                                              days-per-tick]
                                           [set salinity_days 0 ]

      ; Get copy of turtle-context variable salinity_max_days
      let salinity_max_days_ 0
      ask one-of plants [ set salinity_max_days_ salinity_max_days ]

      ; Test for plant death
      let death  false
      let reason ""

      if depth < -100 [ set reason "depth < -100 cm"  set death true ]
      if not death [
        if days_dry_ > 160 [ set reason "days_dry > 160"  set death true ]
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
  ] ; ask Wax_Myrtle_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Red_Bay_patches
    ask dead_patches_ [ set Wax_Myrtle_patches other Wax_Myrtle_patches ]
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
to go-poisonwood
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Poisonwood_patches [

    let plants poisonwoods-here

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
  ] ; ask Poisonwood_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Poisonwood_patches
    ask dead_patches_ [ set Poisonwood_patches other Poisonwood_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to go-gumbo-limbo
;-------------------------------------------------------------------------

  let dead_patches_ no-patches ; local empty patch agentset

  ask Gumbo_Limbo_patches [

    let plants gumbo-limbos-here

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
  ] ; ask Gumbo_Limbo_patches

  if count dead_patches_ > 0 [
    ; Remove dead_patches_ from Gumbo_Limbo_patches
    ask dead_patches_ [ set Gumbo_Limbo_patches other Gumbo_Limbo_patches ]
    ; Add dead_patches_ to global Dead_patches agentset
    set Dead_patches (patch-set Dead_patches dead_patches_)
  ]
end

;-------------------------------------------------------------------------
to init-patches
; Must be called After load-gis-shapefile and init-patch-agentsets
;-------------------------------------------------------------------------
  print "Initializing patches, convert elevation from ft to cm..."
  ask patches [
    ifelse cell_ID > 0 [ ; patch had Cell_ID from the GIS shapefile
      set elevation          elevation * 30.48
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

    let envelope_coord patch_gis_coordinates pxcor pycor
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
;-------------------------------------------------------------------------
  ; setup sawgrass salinity_max to match patch salinity_threshold
  ask Sawgrass_patches [
    ask sawgrass-here [
      set salinity_max       5
      set salinity_max_days 20
    ]
    set salinity_threshold 5
  ]

  ask Spikerush_patches [
    ask spikerushs-here [
      set salinity_max       5
      set salinity_max_days 20
    ]
    set salinity_threshold   5
    set days_wet           100  ; init hydroperiod to 800
  ]

end

;-------------------------------------------------------------------------
to sprout-turtles-on-patches
;-------------------------------------------------------------------------
  ask Black_Mangrove_patches [ sprout-black-mangroves 1 [ init-turtle-vars ] ]
  ask Red_Mangrove_patches   [ sprout-red-mangroves   1 [ init-turtle-vars ] ]
  ask White_Mangrove_patches [ sprout-white-mangroves 1 [ init-turtle-vars ] ]
  ask Buttonwood_patches     [ sprout-buttonwoods     1 [ init-turtle-vars ] ]
  ask Buttonbush_patches     [ sprout-buttonbushs     1 [ init-turtle-vars ] ]
  ask Cypress_patches        [ sprout-cypress         1 [ init-turtle-vars ] ]
  ask Seaside_Oxeye_patches  [ sprout-seaside-oxeyes  1 [ init-turtle-vars ] ]
  ask Mahogany_patches       [ sprout-mahoganies      1 [ init-turtle-vars ] ]
  ask Fan_Palm_patches       [ sprout-fan-palms       1 [ init-turtle-vars ] ]
  ask Paurotis_Palm_patches  [ sprout-paurotis-palms  1 [ init-turtle-vars ] ]
  ask Swamp_Bay_patches      [ sprout-swamp-bays      1 [ init-turtle-vars ] ]
  ask Arrowhead_patches      [ sprout-arrowheads      1 [ init-turtle-vars ] ]
  ask Sawgrass_patches       [ sprout-sawgrass        1 [ init-turtle-vars ] ]
  ask Spikerush_patches      [ sprout-spikerushs      1 [ init-turtle-vars ] ]
  ask Black_Rush_patches     [ sprout-black-rushs     1 [ init-turtle-vars ] ]
  ask Saltwort_patches       [ sprout-saltworts       1 [ init-turtle-vars ] ]
  ask Muhly_Grass_patches    [ sprout-muhly-grass     1 [ init-turtle-vars ] ]
  ask Beakrush_patches       [ sprout-beakrushs       1 [ init-turtle-vars ] ]
  ask Cattail_patches        [ sprout-cattails        1 [ init-turtle-vars ] ]
  ask Morning_Glory_patches  [ sprout-morning-glories 1 [ init-turtle-vars ] ]
  ask Cocoplum_patches       [ sprout-cocoplums       1 [ init-turtle-vars ] ]
  ask Sea_Grape_patches      [ sprout-sea-grapes      1 [ init-turtle-vars ] ]
  ask Gumbo_Limbo_patches    [ sprout-gumbo-limbos    1 [ init-turtle-vars ] ]
  ask Red_Bay_patches        [ sprout-red-bays        1 [ init-turtle-vars ] ]
  ask Sweet_Bay_patches      [ sprout-sweet-bays      1 [ init-turtle-vars ] ]
  ask Pond_Apple_patches     [ sprout-pond-apples     1 [ init-turtle-vars ] ]
  ask Poisonwood_patches     [ sprout-poisonwoods     1 [ init-turtle-vars ] ]
  ask Mixed_Shrub_patches    [ sprout-mixed-shrubs    1 [ init-turtle-vars ] ]
  ask Wax_Myrtle_patches     [ sprout-wax-myrtle      1 [ init-turtle-vars ] ]
  ask Willow_patches         [ sprout-willows         1 [ init-turtle-vars ] ]
  ask Hardwood_Hammock_patches [ sprout-hardwood-hammocks 1 [init-turtle-vars]]
  ask Broadleaf_Marsh_patches  [ sprout-broadleaf-marshes 1 [init-turtle-vars]]
  ask Swamp_Shrubland_patches  [ sprout-swamp-shrublands  1 [init-turtle-vars]]
  ask Swamp_Woodland_patches   [ sprout-swamp-woodlands   1 [init-turtle-vars]]
  ask Hardwood_Woodland_patches[sprout-hardwood-woodlands 1 [init-turtle-vars]]
end

;-------------------------------------------------------------------------
to init-turtle-vars
;-------------------------------------------------------------------------
  ; Copies patch variables read from GIS to sprouted turtles
  ; Called in the context of a patch sprout-breed [ turtle commands ]
  set species        species_init
  set species_end    species_fini
  set binomen        binomen_init
  set abundance      abundance_init
  set min_abundance  min_abundance_init
  set max_abundance  max_abundance_init
  set max_height     max_height_init
  set cohabit        cohabit_init

  set color species_color species ; species_color is a reporter
end

;-------------------------------------------------------------------------
to init-patch-agentsets
;-------------------------------------------------------------------------
  ; Collect species-defined patches into appropriate agent sets
  ; from the species_init field in the GIS DB file for each patch
  set Black_Mangrove_patches patches with
      [ member? species_init[ "Black Mangrove" ] ]

  set Red_Mangrove_patches patches with
      [ member? species_init[ "Red Mangrove" ] ]

  set White_Mangrove_patches patches with
      [ member? species_init[ "White Mangrove" ] ]

  set Buttonwood_patches patches with
      [ member? species_init[ "Buttonwood" ] ]

  set Buttonbush_patches patches with
      [ member? species_init[ "Buttonbush" ] ]

  set Cypress_patches patches with
      [ member? species_init[ "Cypress" ] ]

  set Seaside_Oxeye_patches patches with
      [ member? species_init[ "Seaside Oxeye" ] ]

  set Mahogany_patches patches with
      [ member? species_init[ "Mahogany" ] ]

  set Fan_Palm_patches patches with
      [ member? species_init[ "Fan Palm" ] ]

  set Paurotis_Palm_patches patches with
      [ member? species_init[ "Paurotis Palm" ] ]

  set Swamp_Bay_patches patches with
      [ member? species_init[ "Swamp Bay" ] ]

  set Arrowhead_patches patches with
      [ member? species_init[ "Arrowhead" ] ]

  set Sawgrass_patches patches with
      [ member? species_init[ "Sawgrass" ] ]

  set Spikerush_patches patches with
      [ member? species_init[ "Spikerush" ] ]

  set Black_Rush_patches patches with
      [ member? species_init[ "Black Rush" ] ]

  set Saltwort_patches patches with
      [ member? species_init[ "Saltwort" ] ]

  set Muhly_Grass_patches patches with
      [ member? species_init[ "Muhly Grass" ] ]

  set Beakrush_patches patches with
      [ member? species_init[ "Beakrush" ] ]

  set Cattail_patches patches with
      [ member? species_init[ "Cattail" ] ]

  set Morning_Glory_patches patches with
      [ member? species_init[ "Morning Glory" ] ]

  set Cocoplum_patches patches with
      [ member? species_init[ "Cocoplum" ] ]

  set Sea_Grape_patches patches with
      [ member? species_init[ "Sea Grape" ] ]

  set Gumbo_Limbo_patches patches with
      [ member? species_init[ "Gumbo Limbo" ] ]

  set Red_Bay_patches patches with
      [ member? species_init[ "Red Bay" ] ]

  set Sweet_Bay_patches patches with
      [ member? species_init[ "Sweet Bay" ] ]

  set Pond_Apple_patches patches with
      [ member? species_init[ "Pond Apple" ] ]

  set Poisonwood_patches patches with
      [ member? species_init[ "Poisonwood" ] ]

  set Mixed_Shrub_patches patches with
      [ member? species_init[ "Mixed Shrub" ] ]

  set Hardwood_Hammock_patches patches with
      [ member? species_init[ "Hardwood Hammock" ] ]

  set Broadleaf_Marsh_patches patches with
      [ member? species_init[ "Broadleaf Marsh" ] ]

  set Swamp_Shrubland_patches patches with
      [ member? species_init[ "Swamp Shrubland" ] ]

  set Swamp_Woodland_patches patches with
      [ member? species_init[ "Swamp Woodland" ] ]

  set Hardwood_Woodland_patches patches with
      [ member? species_init[ "Hardwood Woodland" ] ]

  set Wax_Myrtle_patches patches with
      [ member? species_init[ "Wax Myrtle" ] ]

  set Willow_patches patches with
      [ member? species_init[ "Willow" ] ]

  set Open_patches patches with
      [ member? species_init[ "Open" ] ]

  set Dead_patches no-patches
end

;-------------------------------------------------------------------------
to count-patch-agentsets
;-------------------------------------------------------------------------
  let N count Black_Mangrove_patches
  if N > 0 [ print ( word N " patches of Black Mangrove" ) ]

  set N count Red_Mangrove_patches
  if N > 0 [ print ( word N " patches of Red_Mangrove" ) ]

  set N count White_Mangrove_patches
  if N > 0 [ print ( word N " patches of White_Mangrove" ) ]

  set N count Buttonwood_patches
  if N > 0 [ print ( word N " patches of Buttonwood" ) ]

  set N count Buttonbush_patches
  if N > 0 [ print ( word N " patches of Buttonbush" ) ]

  set N count Cypress_patches
  if N > 0 [ print ( word N " patches of Cypress" ) ]

  set N count Seaside_Oxeye_patches
  if N > 0 [ print ( word N " patches of Seaside_Oxeye" ) ]

  set N count Mahogany_patches
  if N > 0 [ print ( word N " patches of Mahogany" ) ]

  set N count Fan_Palm_patches
  if N > 0 [ print ( word N " patches of Fan_Palm" ) ]

  set N count Paurotis_Palm_patches
  if N > 0 [ print ( word N " patches of Paurotis_Palm" ) ]

  set N count Swamp_Bay_patches
  if N > 0 [ print ( word N " patches of Swamp_Bay" ) ]

  set N count Arrowhead_patches
  if N > 0 [ print ( word N " patches of Arrowhead" ) ]

  set N count Sawgrass_patches
  if N > 0 [ print ( word N " patches of Sawgrass" ) ]

  set N count Spikerush_patches
  if N > 0 [ print ( word N " patches of Spikerush" ) ]

  set N count Black_Rush_patches
  if N > 0 [ print ( word N " patches of Black_Rush" ) ]

  set N count Saltwort_patches
  if N > 0 [ print ( word N " patches of Saltwort" ) ]

  set N count Muhly_Grass_patches
  if N > 0 [ print ( word N " patches of Muhly_Grass" ) ]

  set N count Beakrush_patches
  if N > 0 [ print ( word N " patches of Beakrush" ) ]

  set N count Cattail_patches
  if N > 0 [ print ( word N " patches of Cattail" ) ]

  set N count Morning_Glory_patches
  if N > 0 [ print ( word N " patches of Morning_Glory" ) ]

  set N count Cocoplum_patches
  if N > 0 [ print ( word N " patches of Cocoplum" ) ]

  set N count Sea_Grape_patches
  if N > 0 [ print ( word N " patches of Sea_Grape" ) ]

  set N count Gumbo_Limbo_patches
  if N > 0 [ print ( word N " patches of Gumbo_Limbo" ) ]

  set N count Red_Bay_patches
  if N > 0 [ print ( word N " patches of Red_Bay" ) ]

  set N count Sweet_Bay_patches
  if N > 0 [ print ( word N " patches of Sweet_Bay" ) ]

  set N count Pond_Apple_patches
  if N > 0 [ print ( word N " patches of Pond_Apple" ) ]

  set N count Poisonwood_patches
  if N > 0 [ print ( word N " patches of Poisonwood" ) ]

  set N count Mixed_Shrub_patches
  if N > 0 [ print ( word N " patches of Mixed_Shrub" ) ]

  set N count Hardwood_Hammock_patches
  if N > 0 [ print ( word N " patches of Hardwood_Hammock" ) ]

  set N count Broadleaf_Marsh_patches
  if N > 0 [ print ( word N " patches of Broadleaf_Marsh" ) ]

  set N count Swamp_Shrubland_patches
  if N > 0 [ print ( word N " patches of Swamp_Shrubland" ) ]

  set N count Swamp_Woodland_patches
  if N > 0 [ print ( word N " patches of Swamp_Woodland" ) ]

  set N count Hardwood_Woodland_patches
  if N > 0 [ print ( word N " patches of Hardwood_Woodland" ) ]

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
  set yellow_list [ "Black Mangrove" "Red Mangrove" "White Mangrove" ]
  set green_list  [ "Fan Palm" "Swamp Bay" "Arrowhead" "Sawgrass"
                    "Black Rush" "Muhly Grass" "Beakrush"
                    "Cattail" "Morning Glory" ]
  set red_list    [ "Spikerush" "Buttonwood" "Buttonbush" "Seaside Oxeye"
                    "Paurotis Palm" "Saltwort" "Sea Grape" ]
  set blue_list   [ "Mahogany" "Hardwood Hammock" "Swamp Woodland"
                    "Hardwood Woodland" "Willow" "Wax Myrtle" ]
  set brown_list  [ "Cypress" "Cocoplum" "Gumbo Limbo" "Red Bay" "Sweet Bay"
                    "Pond Apple" "Poisonwood" ]
  set pink_list   [ "Mixed Shrub" "Broadleaf Marsh" "Swamp Shrubland" ]
  set magenta_list[ "Open" ]
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
  gis:apply-coverage VegMap "BINOMEN"     binomen_init
  gis:apply-coverage VegMap "ABUNDANCE"   abundance_init
  gis:apply-coverage VegMap "MINABUNDAN"  min_abundance_init
  gis:apply-coverage VegMap "MAXABUNDAN"  max_abundance_init
  gis:apply-coverage VegMap "MAXHEIGHT"   max_height_init
  gis:apply-coverage VegMap "COHABIT"     cohabit_init

  ; Station names for stage and salinity gauges/timeseries
  gis:apply-coverage GaugeZones "STAGE"      stage_gauge
  gis:apply-coverage GaugeZones "SALINITY_G" salinity_gauge
end

;-------------------------------------------------------------------------
; Report GIS (UTM 17R) coordinates for a patch
; arguments are patch x, y coordinates
; returns list [minimum-x maximum-x minimum-y maximum-y] from gis:envelope-of
;-------------------------------------------------------------------------
to-report patch_gis_coordinates [ patch_x patch_y ]
  let this-patch patch patch_x patch_y
  let envelope_coord gis:envelope-of this-patch
  report envelope_coord
end

;-------------------------------------------------------------------------
; Report the color from the color list that holds the species name
;-------------------------------------------------------------------------
to-report species_color [ species_ ]

  let color_ grey

  ; black, gray, white, red, orange, brown, yellow, green,
  ; lime, turquoise, cyan, sky, blue, violet, magenta, pink

  ; NetLogo UGLY semantics for a switch : case statement...
  ifelse member? species_ green_list   [ set color_ green   ] [
  ifelse member? species_ blue_list    [ set color_ blue    ] [
  ifelse member? species_ yellow_list  [ set color_ yellow  ] [
  ifelse member? species_ red_list     [ set color_ red     ] [
  ifelse member? species_ magenta_list [ set color_ magenta ] [
  ifelse member? species_ brown_list   [ set color_ brown   ] [
  if     member? species_ pink_list    [ set color_ pink    ]
  ] ] ] ] ] ]

  report color_
end

;-------------------------------------------------------------------------
; arguments are patch x, y coordinates
;-------------------------------------------------------------------------
;to-report Hydroperiod [ patch_x patch_y ]
;  let hydropatch patch patch_x patch_y
;  let dw 0
;  ask hydropatch [ set dw days_wet ]
;  report dw
;end

;-------------------------------------------------------------------------
; patch argument
;
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
; csv file: BK, LM, TR, E146, TSH, R127
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
; station argument is column name from the Salinity.data
; csv file: BK, LM, MK, TR
;-------------------------------------------------------------------------
to-report Salinity.psu [ station ]
  ifelse station = "None" [
    report 0
  ]
  [
    let salinity-psu time:ts-get Salinity.data date station
    report salinity-psu
  ]
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
81
45
193
105
start-date
2000-01-01
1
0
String

INPUTBOX
194
45
315
105
end-date
2005-12-31
1
0
String

PLOT
9
358
330
508
Stage
Time ticks
NAVD (cm)
0.0
10.0
-5.0
80.0
true
true
"" ""
PENS
"EDEN_17_191" 1.0 0 -2674135 true "" "plot Stage \"Cell_17_191\""
"EDEN_17_172" 1.0 0 -8630108 true "" "plot Stage \"Cell_5_172\""
"EDEN_17_172" 1.0 0 -6459832 true "" "plot Stage \"Cell_17_172\""

PLOT
334
358
639
508
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
"TR" 1.0 0 -2674135 true "" "plot Salinity.psu \"Salinity_ppt\""

PLOT
12
146
400
349
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

SWITCH
81
10
236
43
draw-patches
draw-patches
0
1
-1000

OUTPUT
80
109
400
142
12

INPUTBOX
317
45
397
105
days-per-tick
14.0
1
0
Number

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

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

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

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

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
