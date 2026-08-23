'use strict';
'require view';
'require form';
'require fs';
'require ui';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('tgbot', _('Telegram Bot'),
			_('Настройки Telegram-бота управления роутером. После изменения настроек нажмите «Перезапустить бота».'));

		s = m.section(form.NamedSection, 'config', 'tgbot', _('Настройки'));
		s.addremove = false;

		o = s.option(form.Value, 'token', _('Bot Token'));
		o.password = true;
		o.rmempty = false;
		o.datatype = 'string';

		o = s.option(form.Value, 'chatid', _('Chat ID (ваш user ID в Telegram)'));
		o.rmempty = false;
		o.datatype = 'uinteger';

		o = s.option(form.Value, 'ai_key', _('OpenRouter API Key'),
			_('Ключ для AI-чата (/ai). Получить бесплатно на openrouter.ai/keys. Оставьте пустым, чтобы отключить AI.'));
		o.password = true;
		o.optional = true;
		o.placeholder = 'sk-or-v1-...';

		o = s.option(form.ListValue, 'ai_model', _('AI модель'),
			_('Модель для агента. «Авто» сама выбирает живую бесплатную модель, но может попасться слабая — надёжнее зафиксировать.'));
		o.value('nvidia/nemotron-3-super-120b-a12b:free', 'NVIDIA Nemotron Super 120B (рекомендуется)');
		o.value('openrouter/free', _('Авто (случайная бесплатная)'));
		o.value('google/gemma-4-31b-it:free', 'Google Gemma 4 31B');
		o.value('z-ai/glm-5.2:free', 'Zhipu GLM 5.2');
		o.value('thinkingmachines/inkling-small:free', 'Inkling Small');
		o.value('nvidia/nemotron-nano-9b-v2:free', 'NVIDIA Nemotron Nano 9B');
		o.default = 'nvidia/nemotron-3-super-120b-a12b:free';
		o.optional = true;

		o = s.option(form.Button, '_restart');
		o.title = _('Перезапуск');
		o.inputtitle = _('🔄 Перезапустить бота');
		o.inputstyle = 'apply';
		o.onclick = function() {
			return fs.exec('/etc/init.d/tg-bot', ['restart'])
				.then(function() {
					ui.addNotification(null, E('p', _('Бот перезапущен с новыми настройками')), 'info');
				})
				.catch(function(e) {
					ui.addNotification(null, E('p', _('Ошибка перезапуска: %s').format(e.message)), 'error');
				});
		};

		return m.render();
	}
});
