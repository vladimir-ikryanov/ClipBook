import './App.css';
import React from 'react';

declare const greet: (name: string) => string;

function App() {

    function sayHello() {
        const name = (document.querySelector("#greet-input") as HTMLInputElement)?.value;
        document.querySelector("#greet-msg")!.textContent = greet(name);
    }

    function handleKeyPress(event: React.KeyboardEvent<HTMLInputElement>) {
        if (event.key === 'Enter') {
            (document.querySelector("#greet-btn") as HTMLInputElement)?.click();
        }
    }

    return (
        <div className="container">
            <div className="row">
                <img src="/assets/logo.svg" className="logo" alt="Molybden logo"/>
            </div>
            <h1>Welcome to Molybden!</h1>
            <p>Please enter your name and click the button.</p>
            <div className="row">
                <div>
                    <input id="greet-input" placeholder="Your name" onKeyDown={handleKeyPress}/>
                    <button id="greet-btn" type="button" onClick={sayHello}>Greet</button>
                </div>
            </div>
            <p id="greet-msg"></p>
        </div>
    )
}

export default App;
