#import "@preview/cetz:0.2.2": canvas, plot, draw

#let line_style = (stroke: (paint: black, thickness: 2pt))
#let dashed = (stroke: (dash: "dashed"))
#let fill_aqua = (stroke: none, fill: teal)
#let fill_olive = (stroke: none, fill: maroon)
#canvas({
  plot.plot(size: (7,3),
    legend: "legend.south",
    legend-style: (orientation: ltr, item: (spacing: 0.5)),
    x-tick-step: none,
    x-ticks: (0, 0),
    y-label: $cal(E)(1, 2, x)$,
    x-label: $x$,
    y-tick-step: none,
    y-ticks: ((0, [0]), (1, [1])),
    axis-style: "left",
    x-min: -3,
    x-max: 3,
    y-min: 0,
    y-max: 1,{
    plot.add(((-3,0), (0,0), (0,1), (3,1)), line: "vh", style: line_style)
    plot.add-hline(1, style: dashed)
  })
})
