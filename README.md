# Sumi

Lector y editor minimalista de archivos `.md` para Mac. Abre el archivo listo para leer y, con ⌘E, pasa a editarlo. Guarda solo.

Si se abre la app sin ningún archivo, muestra una pantalla de inicio para soltar un `.md`, abrir uno con el Finder o elegir uno reciente. Vuelve a aparecer al cerrar el último documento.

## Atajos

| Acción | Atajo |
| --- | --- |
| Leer o editar | ⌘E |
| Índice | ⌘\ |
| Abrir rápido (recientes y misma carpeta) | ⌘K |
| Buscar en el texto (modo edición) | ⌘F |
| Ajustes | ⌘, |

## Compilar e instalar

Necesita las herramientas de línea de comandos de Xcode (no hace falta Xcode completo).

```bash
./scripts/install.sh
```

Compila, arma `Sumi.app` y la copia a `/Applications`. Para solo compilar, sin instalar, usa `./scripts/build.sh` (queda en `build.noindex/Sumi.app`; la carpeta termina en `.noindex` para que Spotlight no la muestre junto a la instalada).

Para que los `.md` se abran con Sumi al hacer doble clic, en Ajustes usa **Usar como predeterminada**.

## Ícono

El ícono sale de `Resources/icon.svg`. Si lo cambias, regenera el `.icns` con:

```bash
./scripts/make-icon.sh
```

## Nota técnica

Las vistas usan `State(initialValue:)` directo en vez de `@State`, porque en este SDK `@State` es una macro que solo compila con Xcode completo.
