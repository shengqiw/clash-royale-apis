export const getClan = async (event) => {
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
}