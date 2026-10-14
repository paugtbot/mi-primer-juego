#!/bin/sh
# Construye LocuraTotal.rbxlx a partir de LocuraTotal.server.luau y lo prueba.
# Necesita: rojo (https://rojo.space) y lune (https://lune-org.github.io/docs).
# (El mundo no va dentro del .rbxlx: el script lo construye al darle a Play,
# porque el terreno no se puede guardar desde aquí.)
set -e
cd "$(dirname "$0")/.."

rojo build default.project.json -o LocuraTotal.rbxlx

if [ "$1" != "--sin-pruebas" ]; then
	lune run herramientas/simulacion.luau 25 LocuraTotal.rbxlx
fi
