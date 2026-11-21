import secrets

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

import config
import db
from schemas import MessageCreate, UserRegister

db.init_db()

app = FastAPI()
bearer_scheme = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> str:
    token = credentials.credentials
    username = db.get_user_by_token(token)
    if not username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or unknown API token",
        )
    return username


@app.get("/messages")
def list_inbox_summaries(
    limit: int = Query(default=20, ge=1), current_user: str = Depends(get_current_user)
):
    summaries = db.get_message_summaries(current_user, limit=limit)
    return {"user": current_user, "inbox": summaries}


@app.get("/messages/{message_id}")
def read_message(message_id: int, current_user: str = Depends(get_current_user)):
    message = db.get_message_by_id(message_id, current_user)
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Message not found"
        )
    return message


@app.post("/messages", status_code=status.HTTP_201_CREATED)
def send_message(msg: MessageCreate, current_user: str = Depends(get_current_user)):
    unique_recipients = list(
        dict.fromkeys(r.strip() for r in msg.recipients if r.strip())
    )
    if not unique_recipients:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No valid recipients provided",
        )

    db.insert_messages_bulk(
        recipients=unique_recipients,
        sender=current_user,
        subject=msg.subject,
        body=msg.body,
    )

    return {"status": "sent", "from": current_user}


if __name__ == "__main__":
    import uvicorn

    print(f"Starting server on {config.HOST}:{config.PORT}...")
    uvicorn.run("server:app", host=config.HOST, port=config.PORT, reload=True)
