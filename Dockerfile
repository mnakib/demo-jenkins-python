FROM python:3.8
WORKDIR /app
COPY . /app
RUN pip install flask
EXPOSE 5000
ENTRYPOINT ["python"]
CMD ["app.py"]
