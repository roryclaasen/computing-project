/*
Copyright 2016-2017 Rory Claasen

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
part of Computer_Science_Project;

class StateManager {

	GameHost _host;
	CanvasElement _canvas;

	/// This Map contains the game states and their corresponding keys
	Map<String, State> _states = new Map<String, State>();

	State _current;

	StateManager(this._host, this._canvas) {
		_states['intro'] = new StateIntro(this);
		_states['login'] = new StateLogin(this);
		_states['game'] = new StateGame(this);

		//_current = _states['intro'];
		_current = _states['login'];
		_current.setVisible(true);
	}

	/// Changes the state to [tag]
	/// If tag is null or there is no state called [tag] the state will not change!
	void changeState(String tag) {
		State next = _states[tag];
		if (next == null) {
			log.severe("State '${tag} is null");
			Notify.error("StateManager", "${tag} state is null");
			return;
		}
		_current.setVisible(false);
		_current = next;
		_current.setVisible(true);
	}

	/// Renders the current state
	void render(CanvasRenderingContext2D context) {
		context..setFillColorRgb(200, 200, 200)..fillRect(0, 0, GameHost.width, GameHost.height);
		_current..renderBackground(context)..render(context)..renderGui(context);
	}

	/// Updates the current state
	void update(final double delta) {
		_current..updateBackground(delta)..update(delta)..updateGui(delta);
	}

	GameHost host() {
		return _host;
	}

	CanvasElement canvas() {
		return  _canvas;
	}
}

abstract class State {
	final StateManager _manager;

	HashMap<String, GuiElement> _gui;

	Sprite _background;

	bool _visible = false;

	double _starOffset = 0.0;

	State(this._manager)  {
		_gui = new HashMap<String, GuiElement>();
		init(_manager.canvas());
		if (_background == null) _background = ResourceManager.getSprite("background.blue");
	}

	/// Abstract initializer
	void init(CanvasElement canvas);

	/// Abstrcat render method
	void render(CanvasRenderingContext2D context);

	void renderBackground(CanvasRenderingContext2D context) {
		if (_background != null) if (_background.isComplete()) {
			ImageElement image = _background.getTexture();
			for (int y = 0; y < GameHost.height + _background.height(); y += _background.height()) {
				for (int x = 0; x < GameHost.width; x += _background.width()) {
					context.drawImage(image, x, y - _starOffset);
				}
			}
		}
	}

	void renderGui(CanvasRenderingContext2D context) {
		_gui.values.forEach((element) =>	element.render(context));
	}

	/// Abstrcat update method
	void update(final double delta);

	void updateGui(final double delta) {
		_gui.values.forEach((element) => element.update(delta));
	}

	void updateBackground(final double delta) {
		if (_background != null) {
			_starOffset += delta * 5;
			if (_starOffset >= _background.height()) _starOffset = 0.0;
		}
	}

	bool isVisible() {
		return _visible;
	}

	void setVisible(bool vis) {
		this._visible = vis;
		this._gui.values.forEach((element) => element.setParentVisible(vis));
		onVisibilityChange();
	}

	void onVisibilityChange() {}
}

class StateIntro extends State {

	StateIntro(StateManager _manager) : super(_manager);

	Sprite _logo;

	double _time = 0.0;

	void init(CanvasElement canvas) {
		_logo = ResourceManager.getSprite('logo.roryclaasen.black');
	}

	void render(CanvasRenderingContext2D context) {
		if (_logo.isComplete()) {
			int w = (_logo.width() * 0.75).toInt();
			int h = (_logo.width() * 0.75).toInt();
			context.drawImageScaled(_logo.getTexture(), (GameHost.width / 2) - (w / 2), (GameHost.height / 2) - (h / 2), w, h);
		}
	}

	void update(final double delta) {
		if(_time >= 0)_time += delta;
		if (_time > 2) {
			_time = -1.0;
			_manager.changeState('login');
		}
	}
}

class StateLogin extends State {

	int _xPadding = 75;
	double _hover = 0.0;

	StateLogin(StateManager _manager) : super(_manager);

	Sprite _station = ResourceManager.getSprite("game.enities.station");

	void init(CanvasElement canvas) {
		_gui['play'] = new GuiButtonElement(_manager.canvas(), _xPadding, 200, "Play");
		_gui['token'] = new GuiButtonElement(_manager.canvas(), _xPadding, 275, "Login");
		// _gui['fullscreen'] = new GuiButtonElement(_manager.canvas(), _xPadding, GameHost.height - 100, "FullScreen", true);

		EventStreamProvider eventStreamProvider = new EventStreamProvider<CustomEvent>("GuiEvent");
		eventStreamProvider.forTarget(canvas).listen((e) {
			if (isVisible()) {
				if (e.detail['type'] == 'button') {
					if (e.detail['text'] == (_gui['token'] as GuiButtonElement).getText()) {
						js.context.callMethod(r'$', ['#modelGameLogin']).callMethod('modal', ['show']);
					}
					if (e.detail['text'] == (_gui['play'] as GuiButtonElement).getText()) {
						_manager.changeState('game');
					}
					if (e.detail['text'] == (_gui['fullscreen'] as GuiButtonElement).getText()) {
						screenHandler.setFullScreen(!screenHandler.isFullScreen());
					}
				}
			}
		});

		querySelector('#gameLogin').onClick.listen((event) {
			InputElement input = querySelector('#gameToken') as InputElement;
			String token = input.value;
			if (token != null) if (token.length > 0) {
				_manager.host().userManagement.login(token).then((connected) {
					if (connected) {
						input.parent.classes.remove('has-error');
						Notify.info("Logged in");
						js.context.callMethod(r'$', ['#modelGameLogin']).callMethod('modal', ['hide']);
						_manager.changeState('game');
					} else {
						input.parent.classes.add('has-error');
						Notify.warn("Unable to login");
					}
				});
			}
		});
	}

	void render(CanvasRenderingContext2D context) {
		context.setFillColorRgb(255, 255, 255);
		context.fillText(document.title, _xPadding, 100);
		if (_station.isComplete()) {
			context..save()
    		..translate((GameHost.width / 1.4) + (2 * sin(_hover)), (GameHost.height / 2) + (10 * sin(_hover * 1.5)))
   			..rotate(45 * PI / 180)
   			..drawImage(_station.getTexture(), -_station.width() / 2, -_station.height() / 2)
   			..restore();
		}
	}

	void update(final double delta) {
		_hover += delta;
		if (_hover > 360) _hover = 0.0;
	}
}

class StateGame extends State {

	GameLevel _level;

	StateGame(StateManager _manager) : super(_manager);

	void init(CanvasElement canvas) {
		_gui['score'] = new GuiText("0000", 20, 20 + 25);
	}

	void onVisibilityChange() {
		if (isVisible()) _level = GameLevel.newLevel(_manager.host().userManagement.currentUser);
		else _level = GameLevel.newLevel();
	}

	void render(CanvasRenderingContext2D context) {
		if (_level != null) _level.render(context);
	}

	void update(final double delta) {
		if (_level != null){
			_level.update(delta);
			(_gui['score'] as GuiText).setText(_level.getFormattedScore());
		}
	}
}
