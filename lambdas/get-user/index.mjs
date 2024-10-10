/* global fetch */
export const getUser = async (event) => {
    const unrefinedId = event.queryStringParameters?.id;

    console.log('hello from getUser', event.queryStringParameters);

    if (!unrefinedId) {
        return {
            statusCode: 400,
            headers: {
                "Access-Control-Allow-Origin": "*" 
            },
            body: "Missing id"
        }
    }
    
    const jwtToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzUxMiIsImtpZCI6IjI4YTMxOGY3LTAwMDAtYTFlYi03ZmExLTJjNzQzM2M2Y2NhNSJ9.eyJpc3MiOiJzdXBlcmNlbGwiLCJhdWQiOiJzdXBlcmNlbGw6Z2FtZWFwaSIsImp0aSI6IjMwZTg3ZmJjLTFjZTktNDAxZi05ZjgwLTAxMWE3MzFhNzcyNCIsImlhdCI6MTcyODUxNjgyMywic3ViIjoiZGV2ZWxvcGVyLzIxNjZhMjY0LTk2NjAtMTUxYi1iY2I0LTFiNTE1ODQzY2NiMiIsInNjb3BlcyI6WyJyb3lhbGUiXSwibGltaXRzIjpbeyJ0aWVyIjoiZGV2ZWxvcGVyL3NpbHZlciIsInR5cGUiOiJ0aHJvdHRsaW5nIn0seyJjaWRycyI6WyIzNC4yMzAuMTYyLjE0NCJdLCJ0eXBlIjoiY2xpZW50In1dfQ.L8iqiaQqKb5stziiXPZHppASSDX4vFgBse1x_IY7OJSBDgfjXamO3DnCmbAXB5c6w0MEvKBcDe-qGsZNXmXLJA";
    const playerId = unrefinedId.trim().startsWith("#") ? 
        encodeURIComponent(unrefinedId.trim()) :
        encodeURIComponent(`#${unrefinedId.trim()}`);
    console.log('playerId', playerId);
    const res = await fetch(`https://api.clashroyale.com/v1/players/${playerId}`, {
        headers: {
            "Authorization": `Bearer ${jwtToken}`,
            "Content-Type": "application/json"
        }
    });
    console.log('res', res);
    
    if (res.status === 404) {
        return {
            statusCode: 404,
            body: "Player not found"
        }
    }
    const userData = await res.json();
    
    console.log('userData', userData)
    return {
        statusCode: 200,
        headers: {
            "Access-Control-Allow-Origin": "*" 
        },
        body: JSON.stringify(userData)
    }
}