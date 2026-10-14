#!/bin/sh
# Construye LocuraTotal.rbxlx a partir de LocuraTotal.server.luau y lo prueba.
# Necesita: rojo (https://rojo.space) y lune (https://lune-org.github.io/docs).
set -e
cd "$(dirname "$0")/.."

rojo build default.project.json -o LocuraTotal.rbxlx
lune run herramientas/construir.luau LocuraTotal.rbxlx

if [ "$1" != "--sin-pruebas" ]; then
	lune run herramientas/simulacion.luau 25 LocuraTotal.rbxlx
fi
