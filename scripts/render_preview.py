#!/usr/bin/env python3
"""Render an accurate geometry preview. Optional dependencies: numpy, matplotlib.

This is a render of the generated primitives, not a Roblox engine screenshot.
"""
from pathlib import Path
import math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from build_town import build

geometry = build()
faces, colors, ground_faces, ground_colors = [], [], [], []
light = np.array([-0.4, 0.8, 0.5])
light /= np.linalg.norm(light)
for p in geometry:
    if p["transparent"] > 0.9:
        continue
    w, h, d = (s / 2 for s in p["size"])
    if p["kind"] == "WedgePart":
        vertices = np.array([[-w,-h,-d],[w,-h,-d],[-w,-h,d],[w,-h,d],[-w,h,d],[w,h,d]])
        indices = [[0,2,3,1], [2,4,5,3], [0,1,5,4], [0,4,2], [1,3,5]]
    else:
        vertices = np.array([[-w,-h,-d],[w,-h,-d],[w,-h,d],[-w,-h,d],[-w,h,-d],[w,h,-d],[w,h,d],[-w,h,d]])
        indices = [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]
    a = math.radians(p["yaw"])
    rotation = np.array([[math.cos(a),0,math.sin(a)], [0,1,0], [-math.sin(a),0,math.cos(a)]])
    vertices = vertices @ rotation.T + np.array(p["pos"])
    base = np.array(p["color"]) / 255
    for face in indices:
        points = vertices[face]
        normal = np.cross(points[1]-points[0], points[2]-points[0])
        normal /= max(np.linalg.norm(normal), 0.001)
        shade = 0.76 + 0.24 * max(0, float(normal @ light))
        target_faces, target_colors = (ground_faces, ground_colors) if p["pos"][1] + h <= 1.2 else (faces, colors)
        target_faces.append(points[:, [0,2,1]])
        target_colors.append((*np.clip(base * shade, 0, 1), 0.85 if p["transparent"] > 0 else 1))

fig = plt.figure(figsize=(15, 11), dpi=140, facecolor="#e6efec")
ax = fig.add_axes([0.01,0.02,0.98,0.88], projection="3d", computed_zorder=False)
ax.set_facecolor("#e6efec")
ax.add_collection3d(Poly3DCollection(ground_faces, facecolors=ground_colors, edgecolors="none", zsort="average", zorder=1))
ax.add_collection3d(Poly3DCollection(faces, facecolors=colors, edgecolors="none", zsort="average", zorder=2))
ax.set_xlim(-104,104); ax.set_ylim(-98,98); ax.set_zlim(-15,39)
ax.set_box_aspect((208,196,54)); ax.view_init(elev=33, azim=55)
ax.set_proj_type("ortho"); ax.set_axis_off()
fig.text(0.06,0.94,"TINY TOWN", fontsize=25, weight="bold", color="#23343d")
fig.text(0.06,0.909,"Four destinations. One shared world of queues.", fontsize=12, color="#5a737c")
fig.text(0.06,0.04,"ARENA  /  DOJO  /  ROOFTOPS  /  TRAINING LAB", fontsize=12, weight="bold", color="#344d58")
fig.text(0.06,0.018,"Geometry preview of the included Roblox model", fontsize=9, color="#6d858a")
output = Path(__file__).resolve().parents[1] / "docs/town-preview.png"
fig.savefig(output, facecolor=fig.get_facecolor())
print(output)
