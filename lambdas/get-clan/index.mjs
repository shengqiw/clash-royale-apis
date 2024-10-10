export const getClan = async (event) => {
    const unrefinedId = event.queryStringParameters?.tag;

    console.log('hello from getClan', event.queryStringParameters);

    if (!unrefinedId) {
        return {
            statusCode: 400,
            headers: {
                "Access-Control-Allow-Origin": "*" 
            },
            body: "Missing id"
        }
    }

    return {
        statusCode: 200,
        body: 'Hello from getClan'
    }
}