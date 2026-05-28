#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: hexagon

#align(center)[
  #diagram(
    node-stroke: 1pt,
    edge-stroke: 1pt,
    
    node((1, 0), width: 10pt, height: 10pt, shape: circle, fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%)),
    node((1+0.5, 0), width: 10pt, height: 10pt, shape: circle, fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%)),
    node((1+0.5, 1), width: 10pt, height: 10pt, shape: circle, fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%)),
    node((1, 1), width: 10pt, height: 10pt, shape: circle, fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%)),
    node([Layer], enclose: ((1, 0), (1+0.5, 1)), corner-radius: 5pt, fill: teal.lighten(80%), stroke: 1pt + teal.darken(20%), name: <l1>),
    edge((1+0.5, 0), (1+0.5, 1), "->", stroke: 1pt + yellow.darken(20%)),
    edge((1, 0), (1+0.5, 0), "->", stroke: 1pt + yellow.darken(20%)),
    edge((1, 1), (1, 0), "->", stroke: 1pt + yellow.darken(20%)),
    edge((1, 1), (1+0.5, 1), "->", stroke: 1pt + yellow.darken(20%)),

    node((2, 0), width: 10pt, height: 10pt, shape: circle, fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%)),
    node((2+0.5, 0), width: 10pt, height: 10pt, shape: circle, fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%)),
    node((2+0.5, 1), width: 10pt, height: 10pt, shape: circle, fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%)),
    node((2, 1), width: 10pt, height: 10pt, shape: circle, fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%)),
    node([Layer], enclose: ((2, 0), (2+0.5, 1)), corner-radius: 5pt, fill: teal.lighten(80%), stroke: 1pt + teal.darken(20%), name: <l2>),
    edge((2+0.5, 0), (2+0.5, 1), "->", stroke: 1pt + yellow.darken(20%)),
    edge((2, 0), (2+0.5, 0), "->", stroke: 1pt + yellow.darken(20%)),
    edge((2, 1), (2, 0), "->", stroke: 1pt + yellow.darken(20%)),
    edge((2, 1), (2+0.5, 1), "->", stroke: 1pt + yellow.darken(20%)),

    edge(<l1>, <l2>, "<->", stroke: 1pt + teal.darken(20%)),

    node(enclose: ((0.5,-1), (3,2)), corner-radius: 5pt, stroke: 1pt + blue, align(right + top, [Scene]), name:<scene>),
    node(enclose: ((0,-1.6),(3.5, 2.5)), align(right + top, [User Code]), stroke: (paint: blue, dash: "dashed")),

    let b1_height = 4.5,
    node((0.8, b1_height), [`Update`], corner-radius: 5pt,fill: red.lighten(60%), stroke: 1pt + red.darken(20%), name:<gcupdate>),
    node((2.3, b1_height), [`SceneResultRemap`], corner-radius: 5pt, fill: green.lighten(60%), stroke: 1pt + green.darken(20%), name:<srr>),
    node((3.5, b1_height), [`PostProcessor`], corner-radius: 5pt, fill: green.lighten(60%), stroke: 1pt + green.darken(20%), name:<pp>),

    node(enclose: (<gcupdate>, <srr>, <pp>, (0.3, b1_height - 1)), corner-radius: 5pt,  stroke: (paint: blue, dash: "dashed"), align(right + top, [Global Component]), name:<gccore>),
    edge(<scene>, <gccore>, "->", label: [`GCLoad/GCUnload`], label-side: center),

    let base_height = 5.8,

    node((1.2, base_height + 0.8), [`WorldEvent`], corner-radius: 5pt,fill: red.lighten(60%), stroke: 1pt + red.darken(20%), name:<world>),
    node((1.2, base_height + 1.6), [Elm Subscriptions], corner-radius: 5pt,fill: gray.lighten(60%), stroke: 1pt + gray.darken(20%), name:<sub>),
    node((0.4, base_height), [`GlobalData`], corner-radius: 5pt,fill: red.lighten(60%), stroke: 1pt + red.darken(20%), name:<gd>),
    node((1.2, base_height), [`UserEvent`], corner-radius: 5pt,fill: red.lighten(60%), stroke: 1pt + red.darken(20%), name:<user>),
    edge(<gcupdate>, <scene>, "->"),
    edge(<gd>, <gcupdate>, "->"),
    edge(<user>, <gcupdate>, "->"),
    edge(<sub>, <world>, "->"),
    edge(<world>, <user>, "->", label: "Filter"),
    node((2, base_height), [`GlobalData`], corner-radius: 5pt, fill: green.lighten(60%), stroke: 1pt + green.darken(20%), name:<ngd>),
    node((2.8, base_height), [`SceneOutputMsg`], corner-radius: 5pt, fill: green.lighten(60%), stroke: 1pt + green.darken(20%), name:<som>),
    node((2.8, base_height + 2), [`SOMHandler`], fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%), name:<somhandler>, shape: hexagon),
    node((3.8, base_height + 1), [`ViewHandler`], fill: yellow.lighten(60%), stroke: 1pt + yellow.darken(20%), name:<viewhandler>, shape: hexagon),
    node((3.8, base_height + 2), [Side Effects], corner-radius: 5pt, fill: gray.lighten(60%), stroke: 1pt + gray.darken(20%), name:<sideeff>),
    node((3.8, base_height), [`Renderable`], corner-radius: 5pt, fill: green.lighten(60%), stroke: 1pt + green.darken(20%), name:<render>),
    node((2, base_height + 1.5), [Core Data], corner-radius: 5pt, fill: orange.lighten(60%), stroke: 1pt + orange.darken(20%), name:<cdata>),
    edge(<world>, (2, base_height + 0.8), <cdata>, "-->"),
    edge(<somhandler>, (2.6, base_height + 1.5), <cdata>, "-->"),
    edge(<scene>, <srr>, "->"),
    edge(<srr>, <ngd>, "->"),
    edge(<srr>, <som>, "->"),
    edge(<ngd>, <somhandler>, "->"),
    edge(<som>, <somhandler>, "->"),
    edge(<render>, <viewhandler>, "->"),
    edge(<viewhandler>, <sideeff>, "->"),
    edge(<somhandler>, <sideeff>, "->"),
    edge(<scene>, <pp>, "->"),
    edge(<pp>, <render>, "->"),
    edge(<somhandler> ,(0.4,base_height+2), <gd>, "->"),
    node(enclose: ((0, 3),(4.8, base_height + 2.5)), align(right + top, [Core Code]), stroke: (paint: red, dash: "dashed")),
  )
]
