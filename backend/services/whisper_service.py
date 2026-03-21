import openai
import os
from typing import Dict

# Initialize OpenAI client
openai.api_key = os.getenv('OPENAI_API_KEY')

async def transcribe_audio(audio_file_path: str) -> Dict[str, any]:
    """
    Transcribe audio file using OpenAI Whisper

    Args:
        audio_file_path: Path to audio file on disk

    Returns:
        Dictionary with text, confidence, and language
    """
    try:
        with open(audio_file_path, 'rb') as audio_file:
            transcript = openai.Audio.transcribe(
                model='whisper-1',
                file=audio_file,
                language='tl',  # Filipino
                response_format='json'
            )

        return {
            'text': transcript['text'],
            'confidence': 0.95,  # Whisper doesn't provide confidence scores
            'language': 'tl'
        }

    except openai.APIError as e:
        print(f'Whisper API error: {e}')
        return {
            'text': '',
            'confidence': 0.0,
            'error': str(e)
        }
    except Exception as e:
        print(f'Unexpected error: {e}')
        return {
            'text': '',
            'confidence': 0.0,
            'error': str(e)
        }