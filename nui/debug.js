const DEBUG_LOCALE = {
    "no_permission": "You do not have permission to do this.",
    "header_hit": "Hitman Contracts",
    "available_hits_name": "Target Name",
    "available_hits_date": "Date",
    "available_hits_reward": "Reward",
    "available_hits_accept": "Accept Hit",
    "available_hits_remove": "Remove Hit",
    "available_hits_view": "View Target",
    "select_player_add_hit": "Place Hit",
    "select_player_back": "Back to Player Selection",
    "hit_image_url": "Image URL",
    "hit_reward_amount": "Reward Amount",
    "hit_description": "Description",
    "view_hit": "View Target",
    "player_source": "(ID: %s)",
    "add_new_hit": "Add New Hit",
    "current_hit": "Hit Contract",
    "current_hit_interact_1": "Hold",
    "current_hit_interact_2": "to interact with the contract.",
    "current_hit_name": "Name",
    "current_hit_reward": "Reward",
    "current_hit_description": "Description",
    "current_hit_camera": "Use Camera",
    "current_hit_return": "Return to Game",
    "current_hit_cancel": "Cancel Contract",
}

function DebugSendConfig() {
    let data = {
        loaded: true,
        locale: DEBUG_LOCALE,
        identifier: "hitman",
        permissions: {
            placeHits: true,
            cancelHits: false,
        },
        defaultPlayerImage: "https://cdn.discordapp.com/attachments/888888888888888888/888888888888888888/888888888888888888.png",
        currency: {
            name: "USD",
            locale: "en-US",
        }
    }
    window.postMessage({
        type: 'setConfig',
        ...data
    }, '*');
}

function DebugSetDisplay(visible) {
    window.postMessage({
        type: "setAppDisplay",
        data: visible
    })
}

function DebugSendSections() {
    window.postMessage({
        type: 'setSections',
        sections: [
            {
                name: "hits",
                label: "Hitman Contracts",
            }   
        ]
    }, '*');
    setTimeout(() => {
        DebugSetDisplay(true);
        DebugSendHits();
    }, 100);
}

function DebugSendHits() {
    window.postMessage({
        type: 'updateHits',
        hits: [
            {
                id: "char:abcd",
                image: "nui/images/g_f_y_ballas_01.png",
                description: "Big Baller",
                source: 100,
                issuer: "hitmaan",
                date: 1700023049,
                name: "Big Baller", 
                reward: 1000
            },
        ]
    }, '*');
}

function DebugCurrentHit() {
    window.postMessage({
        type: 'setCurrentHit',
        currentHit: {
            id: "char:abcd",
            image: "nui/images/g_f_y_ballas_01.png",
            description: "This is a big baller description",
            source: 100,
            // hitmanId?: number;
            date: 1700023049,
            name: "Big Baller", 
            reward: 1000
        }
    }, '*');
}

document.addEventListener('DOMContentLoaded', (event) => {
    fetch('https://pickle_hitman/requestConfig', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    }).then((response) => {
        response.json().then((data) => {
            console.log('Sending config data to NUI', data);
            window.postMessage(data, '*');
        });
    });
    // setTimeout(() => {
    //     DebugSendConfig();
    //     setTimeout(() => {
    //         DebugSendSections()
    //     }, 100);
    //     setTimeout(() => {
    //         DebugCurrentHit();
    //     }, 100);
    // }, 1000);
});