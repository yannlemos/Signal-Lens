<p align="center">
  <img width="600" alt="cover" src="https://github.com/user-attachments/assets/e9bc1a22-118b-4107-9658-ad4eb73a0d41">
</p>

<p align="center">
<b>A Visual Debugger for Signals</b><br>
Supports Godot 4.3 and 4.4.
</p>

![Signal Lens 1 3 Hero Image](https://github.com/user-attachments/assets/d6d5733f-a971-419e-8f05-2f7ed8b77e24)

## Features
- Click on a node in the remote scene tree and instantly view all its signals' connections.
- View signal emissions in real-time as they are emitted in-game.
- Select and rearrange a graph view to inspect your signal connections.
- Keep signal emissions so you can inspect them later.
- Modify the signal emission speed so you can fine-tune the experience for your debugging purposes.
- Supports inspection of built-in and custom signals.
- Supports inspection of built-in, custom and autoload nodes — if it's in the remote tree, you can inspect it.
- Draws both anonymous and named callables that are connected to a signal.
- Log every signal emitted.
- Inspection of Object, RefCounted and Resource types not supported (yet!)

## Installation

Signal Lens can be installed from source by downloading the addons folder from the repo into the addons folder in your project, or directly from the [Godot Asset Library](https://godotengine.org/asset-library/asset/3620).

**IMPORTANT**: After installation, go to Project Settings -> Plugins and press Enable on Signal Lens. It will the appear in Godot's debugger panel.

## How To Use

https://github.com/user-attachments/assets/94e6887f-005a-46cc-a618-678cef5f84aa

1. While the project is playing, go to the debugger panel and select the "Signal Lens" tab.
2. Select any node in the remote tree and Signal Lens will instantly draw the node's signal connections.

## Troubleshooting & Contributing

If you have any feature requests, please log a proposal in the [issues](https://github.com/yannlemos/Signal-Lens/issues) tab. <br>
If you encounter any problems, please log a bug on the [issues](https://github.com/yannlemos/Signal-Lens/issues) tab. <br>
Feel free to ask questions or propose ideas in the [discussions](https://github.com/yannlemos/Signal-Lens/discussions) tab. <br>

If you wish to contribute directly to the project, fork the main branch and submit your pull request when ready. 
I'll take a look at it as soon as possible!

## Credits

Developed by [Yann Lemos](https://github.com/yannlemos) and [contributors](https://github.com/yannlemos/Signal-Lens/graphs/contributors) to the repository.
Released under the MIT license.
Special thanks to my friends at Studio Bravarda.

Godot Logo (C) Andrea Calabró, distributed under the terms of the Creative Commons Attribution 4.0 International License (CC-BY-4.0 International) <https://creativecommons.org/licenses/by/4.0/>
