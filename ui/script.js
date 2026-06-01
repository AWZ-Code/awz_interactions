(function () {
    'use strict';

    const state = {
        items: [],
        selectedIndex: 0,
        maxItems: 50,
    };

    const root = document.documentElement;
    const pickerEl = document.getElementById('picker');
    const titleEl = document.getElementById('picker-title');
    const listEl = document.getElementById('picker-list');
    const logoEl = document.getElementById('picker-logo');

    function post(name, data) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function applyTheme(theme) {
        if (!theme) return;

        const map = {
            backgroundColor:    '--picker-bg',
            titleBackground:    '--picker-title-bg',
            textColor:          '--picker-text',
            selectedBackground: '--picker-selected-bg',
            selectedTextColor:  '--picker-selected-text',
            accentColor:        '--picker-accent',
            borderRadius:       '--picker-radius',
            width:              '--picker-width',
            fontFamily:         '--picker-font-family',
            fontSize:           '--picker-font-size',
            titleFontSize:      '--picker-title-font-size',
            itemPadding:        '--picker-item-padding',
            logoSize:           '--picker-logo-size',
        };

        Object.keys(map).forEach((key) => {
            if (theme[key] !== undefined && theme[key] !== null) {
                root.style.setProperty(map[key], theme[key]);
            }
        });

        if (theme.position === 'left') {
            root.style.setProperty('--picker-position-right', 'auto');
            root.style.setProperty('--picker-position-left', '5%');
            root.style.setProperty('--picker-position-transform', 'translateY(-50%)');
        } else if (theme.position === 'center') {
            root.style.setProperty('--picker-position-right', 'auto');
            root.style.setProperty('--picker-position-left', '50%');
            root.style.setProperty('--picker-position-transform', 'translate(-50%, -50%)');
        } else {
            root.style.setProperty('--picker-position-right', '5%');
            root.style.setProperty('--picker-position-left', 'auto');
            root.style.setProperty('--picker-position-transform', 'translateY(-50%)');
        }

        if (theme.showCategoryDot === false) {
            root.style.setProperty('--picker-dot-display', 'none');
        } else {
            root.style.setProperty('--picker-dot-display', 'inline-block');
        }

        if (theme.showLogo !== false && theme.logoUrl) {
            logoEl.src = theme.logoUrl;
            root.style.setProperty('--picker-logo-display', 'block');
        } else {
            logoEl.removeAttribute('src');
            root.style.setProperty('--picker-logo-display', 'none');
        }

        if (theme.showTitle === false) {
            root.style.setProperty('--picker-title-display', 'none');
        } else {
            root.style.setProperty('--picker-title-display', 'block');
        }

        if (typeof theme.maxItems === 'number' && theme.maxItems > 0) {
            state.maxItems = theme.maxItems;
        }
    }


    function buildInteractionPayload(item) {
        if (!item || item.dataset.cancel === '1') {
            return item && item.dataset.cancel === '1' ? { cancel: 1 } : {};
        }

        const payload = {
            x:       parseFloat(item.dataset.x),
            y:       parseFloat(item.dataset.y),
            z:       parseFloat(item.dataset.z),
            heading: parseFloat(item.dataset.heading),
            object:  item.dataset.object ? parseInt(item.dataset.object, 10) : null,
            effect:  item.dataset.effect || null,
        };

        if (item.dataset.scenario) {
            payload.scenario = item.dataset.scenario;
        } else if (item.dataset.animationDict) {
            payload.animation = {
                dict: item.dataset.animationDict,
                name: item.dataset.animationName,
            };
        }

        return payload;
    }

    function notifyMarker(item) {
        if (!item || item.dataset.cancel === '1') {
            post('setInteractionMarker', {});
            return;
        }

        if (item.dataset.object) {
            post('setInteractionMarker', { entity: parseInt(item.dataset.object, 10) });
            return;
        }

        post('setInteractionMarker', {
            x: parseFloat(item.dataset.x),
            y: parseFloat(item.dataset.y),
            z: parseFloat(item.dataset.z),
        });
    }

    function notifyPreview(item) {
        post('setInteractionPreview', buildInteractionPayload(item));
    }

    function refreshSelection() {
        const items = listEl.children;
        for (let i = 0; i < items.length; i++) {
            items[i].classList.toggle('selected', i === state.selectedIndex);
        }
        const current = items[state.selectedIndex];
        if (current && typeof current.scrollIntoView === 'function') {
            current.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
        notifyMarker(current);
        notifyPreview(current);
    }

    function renderPicker(payload) {
        applyTheme(payload.theme);
        titleEl.textContent = payload.title || 'Interactions';

        const interactions = JSON.parse(payload.interactions || '[]');
        listEl.innerHTML = '';

        const limit = Math.min(interactions.length, state.maxItems);

        for (let i = 0; i < limit; i++) {
            const data = interactions[i];
            const div = document.createElement('div');
            div.className = 'picker__item';

            const dot = document.createElement('span');
            dot.className = 'picker__dot';
            div.appendChild(dot);

            const text = document.createElement('span');
            text.textContent = data.displayLabel || '';
            div.appendChild(text);

            div.dataset.x = data.x;
            div.dataset.y = data.y;
            div.dataset.z = data.z;
            div.dataset.heading = data.heading;

            if (data.scenario) {
                div.dataset.scenario = data.scenario;
            } else if (data.animation) {
                div.dataset.animationDict = data.animation.dict;
                div.dataset.animationName = data.animation.name;
            }

            if (data.object) {
                div.dataset.object = data.object;
            }
            if (data.effect) {
                div.dataset.effect = data.effect;
            }

            listEl.appendChild(div);
        }

        const cancelDiv = document.createElement('div');
        cancelDiv.className = 'picker__item cancel';

        const cancelDot = document.createElement('span');
        cancelDot.className = 'picker__dot';
        cancelDiv.appendChild(cancelDot);

        const cancelText = document.createElement('span');
        cancelText.textContent = payload.cancelLabel || 'End Interaction';
        cancelDiv.appendChild(cancelText);

        cancelDiv.dataset.cancel = '1';
        listEl.appendChild(cancelDiv);

        state.selectedIndex = 0;
        refreshSelection();

        pickerEl.classList.remove('hidden');
    }

    function hidePicker() {
        pickerEl.classList.add('hidden');
        post('setInteractionMarker', {});
        post('setInteractionPreview', {});
    }

    function moveSelection(delta) {
        const total = listEl.children.length;
        if (total === 0) return;
        state.selectedIndex = ((state.selectedIndex + delta) % total + total) % total;
        refreshSelection();
    }

    function confirmSelection() {
        const items = listEl.children;
        const selected = items[state.selectedIndex];
        if (!selected) {
            hidePicker();
            return;
        }

        if (selected.dataset.cancel === '1') {
            post('stopInteraction', {});
            hidePicker();
            return;
        }

        post('startInteraction', buildInteractionPayload(selected));
        hidePicker();
    }

    window.addEventListener('message', function (event) {
        const data = event.data || {};

        switch (data.type) {
            case 'showInteractionPicker':
                renderPicker(data);
                break;
            case 'hideInteractionPicker':
                hidePicker();
                break;
            case 'moveSelectionUp':
                moveSelection(-1);
                break;
            case 'moveSelectionDown':
                moveSelection(1);
                break;
            case 'startInteraction':
                confirmSelection();
                break;
        }
    });
})();
