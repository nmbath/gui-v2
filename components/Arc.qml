/*
** Copyright (C) 2021 Victron Energy B.V.
*/

import QtQuick
import QtQuick.Shapes

ShapePath {
	id: path

	property real w
	property real startAngle
	property real endAngle

	readonly property real r: w/2
	readonly property var startOffsets: angleToCoords(degreesToRadians(startAngle))
	readonly property var endOffsets: angleToCoords(degreesToRadians(endAngle))

	function angleToCoords(theta) {
		const x = Math.cos(theta)
		const y = Math.sin(theta)
		return [x, y]
	}

	function degreesToRadians(degrees) {
		return Math.PI/180 * degrees
	}

	strokeColor: "black"
	strokeWidth: 18
	fillColor: "transparent"
	capStyle: ShapePath.RoundCap
	joinStyle: ShapePath.RoundJoin

	startX: path.r + path.startOffsets[1] * path.r
	startY: path.r - path.startOffsets[0] * path.r

	PathArc {
		direction: PathArc.Clockwise
		radiusX: path.r
		radiusY: path.r
		useLargeArc: (endAngle - startAngle) > 180
		x: path.r + path.endOffsets[1] * path.r
		y: path.r - path.endOffsets[0] * path.r
	}
}