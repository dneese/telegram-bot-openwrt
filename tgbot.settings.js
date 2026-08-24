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

		o = s.option(form.ListValue, 'lang', _('Мова / Language / Язык'),
			_('Мова повідомлень бота / Bot message language / Язык сообщений бота'));
		o.value('ru', 'Русский');
		o.value('uk', 'Українська');
		o.value('en', 'English');
		o.default = 'uk';
		o.optional = true;

		o = s.option(form.Value, 'ai_url', _('AI endpoint URL'),
			_('OpenAI-сумісний endpoint. Типово Groq. Інші: OpenRouter https://openrouter.ai/api/v1/chat/completions, Gemini https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'));
		o.optional = true;
		o.placeholder = 'https://api.groq.com/openai/v1/chat/completions';
		o.value('https://api.groq.com/openai/v1/chat/completions', 'Groq');
		o.value('https://openrouter.ai/api/v1/chat/completions', 'OpenRouter');
		o.value('https://generativelanguage.googleapis.com/v1beta/openai/chat/completions', 'Google Gemini');

		o = s.option(form.Value, 'ai_key', _('AI API Key'),
			_('Ключ провайдера: Groq console.groq.com/keys (безкоштовно), OpenRouter openrouter.ai/keys або Gemini aistudio.google.com/apikey'));
		o.password = true;
		o.optional = true;
		o.placeholder = 'gsk_... / sk-or-v1-...';

		o = s.option(form.Value, 'ai_model', _('AI модель (основна)'),
			_('Модель агента. Можна вибрати зі списку або вписати будь-яку іншу. Змінити можна також прямо в чаті командою /model'));
		o.placeholder = 'qwen/qwen3.6-27b';
		o.value('qwen/qwen3.6-27b', 'Qwen 3.6 27B (Groq)');
		o.value('openai/gpt-oss-20b', 'GPT-OSS 20B (Groq)');
		o.value('openai/gpt-oss-120b', 'GPT-OSS 120B (Groq)');
		o.value('nvidia/nemotron-3-super-120b-a12b:free', 'NVIDIA Nemotron 120B (OpenRouter free)');
		o.default = 'qwen/qwen3.6-27b';
		o.optional = true;

		o = s.option(form.Value, 'ai_model_alt', _('AI модель (резерв)'));
		o.placeholder = 'openai/gpt-oss-20b';
		o.value('openai/gpt-oss-20b', 'GPT-OSS 20B');
		o.value('openai/gpt-oss-120b', 'GPT-OSS 120B');
		o.value('nvidia/nemotron-3-super-120b-a12b:free', 'NVIDIA Nemotron 120B (free)');
		o.optional = true;

		o = s.option(form.Value, 'ai_groq_chain', _('Фолбек-ланцюг моделей'),
			_('Список моделей через пробіл: якщо основна впала/в ліміті — пробуються вони (у кожної свій денний ліміт)'));
		o.placeholder = 'qwen/qwen3.6-27b openai/gpt-oss-120b';
		o.optional = true;

		o = s.option(form.Flag, 'watch_quiet', _('Тихий режим вотчера'),
			_('Не надсилати миттєві сповіщення про DHCP-аренди та порти (події лишаються в логу)'));
		o.default = o.disabled;
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

		o = s.option(form.Button, '_restart_watch');
		o.title = _('Вотчер подій');
		o.inputtitle = _('🔄 Перезапустить tg-watch');
		o.inputstyle = 'apply';
		o.onclick = function() {
			return fs.exec('/etc/init.d/tg-watch', ['restart'])
				.then(function() {
					ui.addNotification(null, E('p', _('tg-watch перезапущено')), 'info');
				})
				.catch(function(e) {
					ui.addNotification(null, E('p', _('Ошибка перезапуска: %s').format(e.message)), 'error');
				});
		};

		return m.render();
	}
});
