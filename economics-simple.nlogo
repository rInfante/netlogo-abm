extensions [ rnd ]

breed [households household]
breed [firms firm]
directed-link-breed [provider-firms provider-firm];;type A links
directed-link-breed [employees employee];;type B links 

households-own
[
    reservation-wage-rate-h ;;w_h
    liquidity-h             ;;m_h
    
    planned-monthly-consumption-expenditure ;;c_r_h
]

firms-own
[
    inventory-f    ;;i_f
    liquidity-f    ;;m_f
    wage-rate-f    ;;w_f
    price-f        ;;p_f
    
    work-position-has-been-offered?
    work-position-has-been-accepted?
    num-consecutive-months-all-work-positions-filled
    fired-employee
    monthly-demand-of-consumption-goods;;sales from previous month
    marginal-cost
    inventory-lower-limit
    inventory-upper-limit 
    price-lower-limit
    price-upper-limit    
]

;;to move most of the globals to sliders
globals
[
    num-consecutive-months-with-all-positions-filled-upper-limit    ;;gamma
    wage-growth-rate-uniform-distribution-upper-support             ;;delta
    inventory-upper-limit-ratio                                     ;;uphi-upper
    inventory-lower-limit-ratio                                     ;;uphi-lower
    price-upper-limit-ratio                                         ;;lphi-upper
    price-lower-limit-ratio                                         ;;lphi-lower
    probability-of-setting-new-price                                ;;theta
    price-growth-rate-uniform-distribution-upper-support            ;;upsilon
    probability-of-household-picking-new-provider-firm 
    price-threshold-of-household-picking-new-provider-firm 
    max-number-potential-employers-visited 
    probability-of-household-visiting-potential-new-employer 
    planned-consumption-increase-decaying-rate 
    max-number-provider-firms-visited 
    technology-productivity-parameter                               ;;lambda
    claimed-wage-rate-percentage-reduction-if-unemployed 
]

;;;
;;; SETUP PROCEDURES
;;;

to setup
  clear-all
  
  setup-globals
  setup-households
  setup-firms 
  
  assign-provider-firms
  assign-employees  
  
  ask households [evolve-planned-monthly-consumption-expenditure]
  
  reset-ticks
end

to setup-globals
    set num-consecutive-months-with-all-positions-filled-upper-limit 24
    set wage-growth-rate-uniform-distribution-upper-support 0.019       
    set inventory-upper-limit-ratio 1.0                                 
    set inventory-lower-limit-ratio 0.25                                
    set price-upper-limit-ratio 1.15                                    
    set price-lower-limit-ratio 1.025                                   
    set probability-of-setting-new-price 0.75                          
    set price-growth-rate-uniform-distribution-upper-support 0.02       
    set probability-of-household-picking-new-provider-firm 0.25
    set price-threshold-of-household-picking-new-provider-firm 0.01
    set max-number-potential-employers-visited 5
    set probability-of-household-visiting-potential-new-employer 0.1
    set planned-consumption-increase-decaying-rate 0.75
    set max-number-provider-firms-visited 7
    set technology-productivity-parameter 3.0                           
    set claimed-wage-rate-percentage-reduction-if-unemployed 0.10  
end

to setup-households
   set-default-shape households "house"
   create-households number-of-households
     [
       setxy random-xcor random-ycor
       set color green
       
       assign-reservation-wage-rate-h
       assign-liquidity-h       
     ]
end

to setup-firms
  set-default-shape firms "square"

  create-firms number-of-firms
     [
       setxy random-xcor random-ycor
       set color green
       set size 2
       
       assign-inventory-f
       assign-liquidity-f
       assign-wage-rate-f
       assign-price-f
       
       set work-position-has-been-offered? false
       set work-position-has-been-accepted? false
       set num-consecutive-months-all-work-positions-filled 0
       set fired-employee nobody
       set monthly-demand-of-consumption-goods inventory-f * 0.80 ;;TODO: must evolve this to at the beginning / end of the month: aggregated purchases from consumers?
       set marginal-cost price-f * 0.90 ;;TODO: must evolve this to at the beginning / end of the month: aggregated purchases from consumers?
     ]  
end

;;;
;;; HOUSEHOLD setup procedures
;;;

to assign-reservation-wage-rate-h
  set reservation-wage-rate-h random-near average-reservation-wage-rate-h
end

to assign-liquidity-h
  set liquidity-h random-near average-liquidity-h
end

to assign-provider-firms ;
  ask households
     [
       let firms-count count firms
       let number-of-provider-firms cap-value (random-near average-number-of-provider-firms) firms-count

       connect-to-n-random-firms number-of-provider-firms
     ]  
end

to connect-to-n-random-firms [n]
  connect-to-firms (n-of n firms)
end

to connect-to-firms [fs]
  create-provider-firms-to fs
end

to assign-employees 
  ask households 
     [
       become-employee-of-random-firm
     ]  
end

to become-employee-of-random-firm
  become-employee-of-firm one-of firms 
end

to become-employee-of-firm [f] 
  create-employee-to f [set color blue]
end

;;;
;;; FIRM setup procedures
;;;

to assign-inventory-f
  set inventory-f random-near average-inventory-f
end

to assign-liquidity-f
  set liquidity-f random-near average-liquidity-f
end

to assign-wage-rate-f
  set wage-rate-f random-near average-wage-rate-f
end

to assign-price-f
  set price-f random-near average-price-f
end

;;;
;;; common setup procedures
;;;

to-report random-near [center]  ;; turtle procedure
  let result 0
  repeat 40
    [ set result (result + random-float center) ]
  report result / 20
end

to-report random-near-int [center]  ;; turtle procedure
  report floor random-normal center (center * 0.2)
end

;;;
;;; GO PROCEDURES
;;;

to go  
  let days ticks + 1
  if is-first-day-of-month? days [evolve-first-day-of-month]
  if is-last-day-of-month? days [evolve-last-day-of-month]
  evolve-normal-day   
  tick
end

to evolve-first-day-of-month
  ask firms 
    [
      fire-employee
      evolve-inventory-lower-upper-limits
      evolve-price-lower-upper-limits
      evolve-num-consecutive-months-with-all-positions-filled
      evolve-wage-rate
      evolve-work-positions
      evolve-goods-price    
      
      evolve-monthly-demand-of-consumption-goods
      evolve-marginal-costs
    ]
  ask households 
    [
      evolve-provider-firms
      evolve-employer
      evolve-planned-monthly-consumption-expenditure

    ]
end


to evolve-last-day-of-month
  ask firms 
    [
      evolve-liquidity-from-paying-salaries
    ]
  ask households 
    [
      evolve-claimed-wage-rate
    ]
    
  file-open "c:\\temp\\unemployment-figures1.txt"
  file-write (count households with [get-employer = nobody]) file-write "," file-print (count firms with [work-position-has-been-offered? = true])
  file-flush
end

;;
;; normal day
;;

to evolve-normal-day
  ask firms 
    [    
      evolve-inventory
    ]
  ask households 
    [
      evolve-liquidity-from-daily-purchases
    ]
end

;;
;; FIRM first-day-of-month
;;

to fire-employee
   if fired-employee != nobody 
      [
        let connection-to-fired-employee in-employee-from fired-employee
        if connection-to-fired-employee != nobody
           [ask connection-to-fired-employee [ die ]]
        set fired-employee nobody
        ;;set num-work-positions-filled (decrement-floored-to-zero num-work-positions-filled);;REMOVE
        set num-consecutive-months-all-work-positions-filled 0
      ] 
end

to evolve-inventory-lower-upper-limits
  set inventory-lower-limit inventory-lower-limit-ratio * monthly-demand-of-consumption-goods
  set inventory-upper-limit inventory-upper-limit-ratio * monthly-demand-of-consumption-goods
end

to evolve-price-lower-upper-limits
  set price-lower-limit price-lower-limit-ratio * marginal-cost
  set price-upper-limit price-upper-limit-ratio * marginal-cost
end

to evolve-num-consecutive-months-with-all-positions-filled
  set num-consecutive-months-all-work-positions-filled (increment num-consecutive-months-all-work-positions-filled)
  ;;this is reset to 0 only one employee is fired
end

to evolve-wage-rate
   let mu random-float wage-growth-rate-uniform-distribution-upper-support
   ifelse work-position-has-been-offered? = true and work-position-has-been-accepted? = false
     [set wage-rate-f increase-by-factor wage-rate-f mu]
     [
       if num-consecutive-months-all-work-positions-filled >= num-consecutive-months-with-all-positions-filled-upper-limit
         [set wage-rate-f decrease-by-factor wage-rate-f mu]
     ]
end

to evolve-work-positions
  evolve-work-position-has-been-offered
  evolve-fired-employee
end

to evolve-work-position-has-been-offered     
   ifelse inventory-f <= inventory-lower-limit
      [
        set work-position-has-been-offered? true
      ]
      [set work-position-has-been-offered? false]
   set work-position-has-been-accepted? false ;;this will be set to true on daily ticks
end

to evolve-fired-employee
  ifelse not any? my-in-employees
     [set fired-employee nobody]
     [ifelse inventory-f >= inventory-upper-limit
        [
           set fired-employee one-of in-employee-neighbors
        ]
        [set fired-employee nobody] 
     ]
end

to evolve-goods-price
   let ni random-float price-growth-rate-uniform-distribution-upper-support
   ifelse inventory-f <= inventory-lower-limit
      [if price-f <= price-upper-limit
         [set price-f increase-with-probability probability-of-setting-new-price price-f ni]]
      [if price-f >= price-upper-limit
         [set price-f decrease-with-probability probability-of-setting-new-price price-f ni]]   
end

to evolve-monthly-demand-of-consumption-goods
  set monthly-demand-of-consumption-goods 0 ;;this is reset at the beginning of every month
end

to evolve-marginal-costs
  ;;THERE IS NO LOGIC TO EVOLVE marginal-costa
end


;;
;; HOUSEHOLD first-day-of-month
;;

to evolve-provider-firms
  let is-event-happening is-happening-with-probability? probability-of-household-picking-new-provider-firm
  if is-event-happening
     [
       let chosen-connected-provider-link one-of my-out-provider-firms
       let chosen-connected-provider-firm [end2] of chosen-connected-provider-link
       let chosen-unconnected-provider-firm choose-unconnected-firm-randomly-weighted-on-employee-count
       let price-of-chosen-connected-provider-firm [price-f] of chosen-connected-provider-firm
       let price-of-chosen-unconnected-provider-firm [price-f] of chosen-unconnected-provider-firm
       let price-percent-difference percent-difference price-of-chosen-connected-provider-firm price-of-chosen-unconnected-provider-firm
       if price-percent-difference < (0.0 - price-threshold-of-household-picking-new-provider-firm)
          [
            ask chosen-connected-provider-link [ die ] ;;remove previous provider firm link
            create-provider-firm-to chosen-unconnected-provider-firm
          ]
     ]
   ;;TODO(*must further evolve Provider firms based on unfulfilled demand of some providers: beginning of page 11*)
end

to-report choose-unconnected-firm-randomly-weighted-on-employee-count
  let unconnected-firms except firms out-provider-firm-neighbors
  report rnd:weighted-one-of unconnected-firms [count in-employee-neighbors]
end

to evolve-employer
  let employer get-employer
  ifelse employer = nobody 
     [try-set-new-employer max-number-potential-employers-visited] ;;unemployed
     [
       let current-employer-wage-rate [wage-rate-f] of employer
       ifelse reservation-wage-rate-h < current-employer-wage-rate ;;unhappy employee
          [try-set-new-employer 1]
          [
             let is-event-happening is-happening-with-probability? probability-of-household-visiting-potential-new-employer
             if is-event-happening    
                [try-set-new-employer 1]        
          ]
     ]
end

to-report get-employer
  report one-of out-employee-neighbors
end

to try-set-new-employer [n-tries]
  let i n-tries
  let employer-set? false
  while [i > 0 and not employer-set?]
     [
       let chosen-potential-employer-firm one-of firms   
       if [work-position-has-been-offered? and (not work-position-has-been-accepted?)] of chosen-potential-employer-firm
          and ([wage-rate-f] of chosen-potential-employer-firm) > reservation-wage-rate-h
          [
            ask my-out-employees [die] ;; kill link to current employer, if any
            ask chosen-potential-employer-firm 
               [                 
                 set work-position-has-been-accepted? true
               ]            
            become-employee-of-firm chosen-potential-employer-firm

            set employer-set? true            
          ] 
       set i (decrement i)     
     ]
end

to evolve-planned-monthly-consumption-expenditure
  let average-goods-price-of-provider-firms mean [price-f] of out-provider-firm-neighbors
  let liquidity-ratio liquidity-h / average-goods-price-of-provider-firms
  set planned-monthly-consumption-expenditure (min (list (liquidity-ratio ^ planned-consumption-increase-decaying-rate) liquidity-ratio))
end

;;
;; FIRM normal day
;;

to evolve-inventory
  set inventory-f (increase-by-amount inventory-f (technology-productivity-parameter * (count my-in-employees)))
  ;;show inventory-f
end

;;
;; HOUSEHOLD normal day
;;

to evolve-liquidity-from-daily-purchases
  try-to-transact-with-provider-firms
end

to try-to-transact-with-provider-firms
  let planned-daily-consumption-demand planned-monthly-consumption-expenditure / days-in-one-month
  let n-tries max-number-provider-firms-visited 
  transact-with-provider-firm  n-tries planned-daily-consumption-demand
end

to transact-with-provider-firm [n-tries planned-daily-consumption-demand]
  let i 0
  let satisfied-demand? false
  let daily-unsatisfied-satisfied-demand planned-daily-consumption-demand
  
  while [i < n-tries and not satisfied-demand?]
     [
       let chosen-provider-firm one-of out-provider-firm-neighbors  
       let chosen-provider-firm-inventory [inventory-f] of chosen-provider-firm
       let chosen-provider-firm-price [price-f] of chosen-provider-firm
       let chosen-provider-firm-liquidity [liquidity-f] of chosen-provider-firm  
       ifelse chosen-provider-firm-inventory > daily-unsatisfied-satisfied-demand
         [
           ifelse (liquidity-h >= chosen-provider-firm-price * daily-unsatisfied-satisfied-demand)
           [
             let purchase-quantity daily-unsatisfied-satisfied-demand
             let purchase-cost (chosen-provider-firm-price * purchase-quantity)                       
             
             buy-goods purchase-quantity purchase-cost chosen-provider-firm
             
             set daily-unsatisfied-satisfied-demand 0.0             
             set satisfied-demand? true
           ]
           [
             let adjusted-daily-consumption-demand div floor (liquidity-h) floor (chosen-provider-firm-price)
             
             let purchase-quantity adjusted-daily-consumption-demand
             let purchase-cost (chosen-provider-firm-price * purchase-quantity)                       
             
             buy-goods purchase-quantity purchase-cost chosen-provider-firm
             
             set daily-unsatisfied-satisfied-demand 0.0
             set satisfied-demand? true
           ]
         ]
         [                         
           let adjusted-daily-consumption-demand chosen-provider-firm-inventory
           
           let purchase-quantity adjusted-daily-consumption-demand
           let purchase-cost (chosen-provider-firm-price * purchase-quantity)                       
           
           buy-goods purchase-quantity purchase-cost chosen-provider-firm
           
           set daily-unsatisfied-satisfied-demand (decrease-by-amount daily-unsatisfied-satisfied-demand purchase-quantity)
           
           if (i >= n-tries) or (daily-unsatisfied-satisfied-demand < 0.05 * planned-daily-consumption-demand)
             [
               set satisfied-demand? true
             ]                       
         ]        
     set i (i + 1)     
   ]  
end

to buy-goods [purchase-quantity purchase-cost chosen-provider-firm]
  set liquidity-h floor-to-zero (decrease-by-amount liquidity-h purchase-cost)
  
  ask chosen-provider-firm
    [      
      set inventory-f (decrease-by-amount inventory-f purchase-quantity)
      set monthly-demand-of-consumption-goods (increase-by-amount monthly-demand-of-consumption-goods purchase-quantity)
      set liquidity-f floor-to-zero (increase-by-amount liquidity-f purchase-cost)              
    ]
end

;;
;; FIRM last-day-of-month
;;

to evolve-liquidity-from-paying-salaries
  ;;TODO:check for possibly negative liquidiy
  let paid-salaries (count  my-in-employees) * wage-rate-f
  let salary wage-rate-f
  ask in-employee-neighbors [pay-salary salary]
  
  ;;TODO:check for possibly negative pnl
  if (count employees) > 0
  [
    let pnl (liquidity-f - paid-salaries)
    let total-employees-liquidity sum [liquidity-h] of in-employee-neighbors
    ask in-employee-neighbors [pay-salary (liquidity-h / total-employees-liquidity) * pnl] ;;pay bonus (if pnl > 0) or charge employee (if pnl < 0)
  ]
  set liquidity-f 0.0
end

;;
;; HOUSEHOLD last-day-of-month
;;

to pay-salary [s] ;;salary
  set liquidity-h floor-to-zero (increase-by-amount liquidity-h s)
end

to evolve-claimed-wage-rate
  let employer get-employer
  ifelse employer = nobody
  [
    set reservation-wage-rate-h (1.0 - claimed-wage-rate-percentage-reduction-if-unemployed) * reservation-wage-rate-h
  ]
  [
    let firm-wage-rate [wage-rate-f] of employer
    if firm-wage-rate > reservation-wage-rate-h
      [set reservation-wage-rate-h firm-wage-rate]        
  ]
end


;;
;; COMMON go procedures
;;

to-report is-first-day-of-month? [days]
  report (days mod days-in-one-month) = 1
end

to-report is-last-day-of-month? [days]
  report (days mod days-in-one-month) = 0
end

to-report increase-by-factor [v f]
  report v * (1.0 + f)
end

to-report decrease-by-factor [v f]
  report v * (1.0 - f)
end


to-report increase-by-amount [v f]
  report v + f
end

to-report decrease-by-amount [v f]
  report v - f
end

to-report is-happening-with-probability? [p] ;;p is decimal value
  report (random-float 100.0) < (p * 100.0)
end

to-report increase-with-probability [p v f] ;; probability, value, factor
  ifelse is-happening-with-probability? p
    [report increase-by-factor v f]
    [report v]
end  
to-report decrease-with-probability [p v f] ;; probability, value, factor
  ifelse is-happening-with-probability? p
    [report decrease-by-factor v f]
    [report v]
end   

to-report floor-to-zero [v]
  ifelse v < 0 [report 0][report v]
end

to-report percent-difference [n1 n2] ;;Number1 and Number2 are between 0.0 and 1.0 (they are 
  report (n2 - n1) / n1
end

to-report div [n d]
  report floor n / d
end

to-report cap-value [v c]
  ifelse v > c [report c][report v]
end

to-report floor-value [v f]
  ifelse v < f [report f][report v]
end

to-report decrement [v]
  report v - 1
end

to-report decrement-floored-to-zero [v]
  report decrement floor-value (v - 1) 0
end

to-report increment [v]
  report v + 1
end

;;
;; set operations
;;

to-report union [set-a set-b]
  report (turtle-set set-a set-b)
end

to-report intersection [set-a set-b]
  report set-a with [member? self set-b]
end

to-report except [set-a set-b]
  report set-a with [not member? self set-b]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
21
663
469
17
16
12.66
1
10
1
1
1
0
1
1
1
-17
17
-16
16
1
1
1
ticks
30.0

SLIDER
4
23
178
56
number-of-households
number-of-households
0
2000
1000
1
1
NIL
HORIZONTAL

SLIDER
5
66
177
99
number-of-firms
number-of-firms
0
100
91
1
1
NIL
HORIZONTAL

BUTTON
10
128
73
161
setup
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
103
128
166
161
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
667
15
905
48
average-reservation-wage-rate-h
average-reservation-wage-rate-h
300
3000
1200
50
1
NIL
HORIZONTAL

SLIDER
666
55
838
88
average-liquidity-h
average-liquidity-h
1
10000
3601
100
1
NIL
HORIZONTAL

SLIDER
1070
13
1254
46
average-inventory-f
average-inventory-f
50
5000
400
10
1
NIL
HORIZONTAL

SLIDER
1070
56
1242
89
average-liquidity-f
average-liquidity-f
1000
200000
35200
100
1
NIL
HORIZONTAL

SLIDER
1072
94
1246
127
average-wage-rate-f
average-wage-rate-f
300
2000
1000
10
1
NIL
HORIZONTAL

SLIDER
1071
136
1243
169
average-price-f
average-price-f
10
200
30
10
1
NIL
HORIZONTAL

SLIDER
666
96
899
129
average-number-of-provider-firms
average-number-of-provider-firms
1
20
7
1
1
NIL
HORIZONTAL

SLIDER
11
179
176
212
days-in-one-month
days-in-one-month
20
31
21
1
1
NIL
HORIZONTAL

MONITOR
672
184
798
229
number-unemployed
count households with [get-employer = nobody]
17
1
11

MONITOR
804
185
913
230
perc-unemployed
(count households with [get-employer = nobody])/(number-of-households) * 100
17
1
11

MONITOR
1072
191
1182
236
mean-inventory-f
mean [inventory-f] of firms
17
1
11

MONITOR
1192
242
1321
287
mean-demand-goods
mean [monthly-demand-of-consumption-goods] of firms
17
1
11

MONITOR
1326
243
1400
288
mean-price
mean [price-f] of firms
17
1
11

MONITOR
672
236
773
281
mean-liquidity-h
mean [liquidity-h] of households
17
1
11

MONITOR
671
288
785
333
mean-wage-asked
mean [reservation-wage-rate-h] of households
17
1
11

MONITOR
1073
297
1185
342
mean-wage-given
mean [wage-rate-f] of firms
17
1
11

MONITOR
1073
241
1162
286
mean-liquidity
mean [liquidity-f] of firms
17
1
11

MONITOR
1072
348
1210
393
firms-with-pos-offered
count firms with [work-position-has-been-offered? = true]
17
1
11

MONITOR
1212
349
1359
394
firms-with-pos-accepted
count firms with [work-position-has-been-accepted? = true]
17
1
11

MONITOR
1191
189
1299
234
mean-inv-up-limit
mean [inventory-upper-limit] of firms
17
1
11

MONITOR
1309
188
1414
233
mean-in-low-limit
mean [inventory-lower-limit] of firms
17
1
11

MONITOR
12
242
99
287
num-months
ticks / days-in-one-month
17
1
11

MONITOR
15
306
72
351
years
ticks / days-in-one-month / 12
17
1
11

PLOT
674
404
1360
770
unemployment
time
unemployment %
0.0
50.0
0.0
10.0
true
true
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (count households with [get-employer = nobody])/(count households) * 100"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 5.2.0
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
